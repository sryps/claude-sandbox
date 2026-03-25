# Choreo Framework Template

Use this template for: consensus algorithms (PBFT, Tendermint, HotStuff, Raft), Byzantine fault tolerant protocols, distributed coordination, message-passing systems, multi-phase commit protocols.

**Prerequisite**: Choreo framework must be available at `specs/choreo/`. If not present, the user needs to set it up first.

## Architecture: Roles + Messages + Stages + Listeners + Effects

Choreo provides the distributed system scaffolding. You define protocol-specific types, listeners (transition functions), and a main listener that combines them.

## Template

```quint
module ProtocolName {
  import basicSpells.* from "spells/basicSpells"
  import choreo(processes = NODES) as choreo from "choreo"

  // ═══════════════════════════════════════════
  // 1. AUXILIARY TYPES — Protocol-specific
  // ═══════════════════════════════════════════
  type Role = Leader | Follower
  type Stage = StagePropose | StageVote | StageDecide

  // ═══════════════════════════════════════════
  // 2. MANDATORY CHOREO TYPES
  // ═══════════════════════════════════════════
  type Node = str

  type Message =
    | MsgPropose({ sender: Node, value: int })
    | MsgVote({ sender: Node, value: int })
    | MsgDecide({ sender: Node, value: int })

  type StateFields = {
    role: Role,
    stage: Stage,
    round: int,
    // Add protocol-specific state fields
  }

  type CustomEffects = ()   // Use () if no custom effects
  type Event = ()           // Use () if no external events
  type Extensions = ()      // Use () if no extensions

  // ═══════════════════════════════════════════
  // 3. BOILERPLATE TYPE ALIASES — Copy as-is
  // ═══════════════════════════════════════════
  type LocalState = choreo::LocalState[Node, StateFields]
  type LocalContext = choreo::LocalContext[Node, StateFields, Message, Event, Extensions]
  type Transition = choreo::Transition[Node, StateFields, Message, Event, CustomEffects]
  type GlobalContext = choreo::GlobalContext[Node, StateFields, Message, Event, Extensions]

  // ═══════════════════════════════════════════
  // 4. HELPER FUNCTIONS — Extract info from messages
  // ═══════════════════════════════════════════
  pure def get_votes(msgs: Set[Message]): Set[Node] = {
    msgs.filterMap(m => match m {
      | MsgVote(v) => Some(v.sender)
      | _ => None
    })
  }

  // ═══════════════════════════════════════════
  // 5. LISTENER FUNCTIONS — One per protocol transition
  // ═══════════════════════════════════════════

  /// Leader proposes a value
  pure def on_propose(ctx: LocalContext): Set[Transition] = {
    if (ctx.state.role == Leader and ctx.state.stage == StagePropose) {
      Set({
        effects: Set(choreo::Broadcast(MsgPropose({ sender: ctx.me, value: 42 }))),
        post_state: { ...ctx.state, stage: StageVote },
      })
    } else {
      Set()
    }
  }

  /// Node votes on received proposal
  pure def on_vote(ctx: LocalContext): Set[Transition] = {
    val proposals = ctx.messages.filterMap(m => match m {
      | MsgPropose(p) => Some(p)
      | _ => None
    })
    if (ctx.state.stage == StageVote and proposals.size() > 0) {
      Set({
        effects: Set(choreo::Broadcast(MsgVote({ sender: ctx.me, value: 42 }))),
        post_state: { ...ctx.state, stage: StageDecide },
      })
    } else {
      Set()
    }
  }

  // ═══════════════════════════════════════════
  // 6. MAIN LISTENER — Combines all listeners
  // ═══════════════════════════════════════════
  pure def main_listener(ctx: LocalContext): Set[Transition] = {
    Set(
      on_propose(ctx),
      on_vote(ctx),
    ).flatten()
  }

  // ═══════════════════════════════════════════
  // 7. CONSTANTS — Nodes and configuration
  // ═══════════════════════════════════════════
  pure val NODE_A: Node = "nodeA"
  pure val NODE_B: Node = "nodeB"
  pure val NODE_C: Node = "nodeC"
  pure val NODES = Set(NODE_A, NODE_B, NODE_C)

  // ═══════════════════════════════════════════
  // 8. INITIALIZATION
  // ═══════════════════════════════════════════
  pure def initialize(n: Node): LocalState = {
    {
      process_id: n,
      role: if (n == NODE_A) Leader else Follower,
      stage: StagePropose,
      round: 0,
    }
  }

  // ═══════════════════════════════════════════
  // 9. STATE MACHINE SETUP
  // ═══════════════════════════════════════════
  action init = choreo::init({
    system: NODES.mapBy(n => initialize(n)),
    messages: NODES.mapBy(n => Set()),
    events: NODES.mapBy(n => Set()),
    extensions: (),
  })

  action step = choreo::step(main_listener, (c, _) => c)

  // ═══════════════════════════════════════════
  // 10. INVARIANTS — Safety properties
  // ═══════════════════════════════════════════
  val consistency = NODES.forall(n1 =>
    NODES.forall(n2 =>
      not(choreo::s.system.get(n1).stage == StageDecide
        and choreo::s.system.get(n2).stage == StagePropose)
    )
  )

  // ═══════════════════════════════════════════
  // 11. WITNESSES — Listener reachability
  // ═══════════════════════════════════════════
  val wit_reaches_decide = NODES.exists(n =>
    choreo::s.system.get(n).stage != StageDecide
  )

  // ═══════════════════════════════════════════
  // 12. TESTING HELPER
  // ═══════════════════════════════════════════
  action step_with(v: Node, listener: LocalContext => Set[Transition]): bool =
    choreo::step_with(v, listener, (c, _) => c)
}
```

## Choreo Key Concepts

### Listeners
- Pure functions: `LocalContext => Set[Transition]`
- Return `Set()` when conditions not met (no transition)
- Return `Set({effects: ..., post_state: ...})` when conditions met
- Multiple possible transitions = multiple elements in the set

### Effects
- `choreo::Broadcast(message)` — send to all nodes
- `choreo::Send(target, message)` — send to specific node
- `Set()` — no effects (local state change only)

### State Access in Invariants/Witnesses
- `choreo::s.system.get(node)` — get a node's local state
- `choreo::s.messages.get(node)` — get messages received by a node

### Main Listener Pattern
Always flatten combined listeners:
```quint
pure def main_listener(ctx: LocalContext): Set[Transition] = {
  Set(listener1(ctx), listener2(ctx), listener3(ctx)).flatten()
}
```

## Choreo Test File Template

```quint
module protocolTest {
  import ProtocolName(
    NODES = Set("node1", "node2", "node3"),
  ).* from "./protocol"
  import basicSpells.* from "spells/basicSpells"

  // Basic happy-path test
  run basicHappyPathTest = {
    val msg = MsgPropose({ sender: "node1", value: 42 })
    init
      .then("node1".with_cue(on_propose, msg).perform(on_propose))
      .then("node2".with_cue(on_vote, msg).perform(on_vote))
      .expect(s.system.get("node2").stage == StageDecide)
  }

  // Timeout test
  run timeoutTest = {
    init
      .then("node1".step_with(on_timeout))
      .then("node2".step_with(on_timeout))
      .expect(NODES.forall(n => s.system.get(n).round == 1))
  }

  // Verify all nodes reach state
  run allNodesTest = {
    init
      // ... actions ...
      .expect(NODES.forall(n => s.system.get(n).stage == StageDecide))
  }
}
```

### Test Helper Patterns

- `.with_cue(listener, params).perform(action)` — execute specific listener with params
- `.step_with(listener)` — execute listener without params (timeouts, internal events)
- `.step_with_messages(listener_fn, msg_fn)` — inject messages and filter listeners
- `.find(predicate).unwrap()` — extract specific messages from sets
- `.expect(predicate)` — verify state after each step
- `NODES.forall(n => condition)` — verify all nodes satisfy condition
