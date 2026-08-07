"""
Leave Approval Workflow — LangGraph Version
--------------------------------------------
Graph shape (matches the requested diagram):

    START
      |
    Get Employee Details
      |
    Check Leave Days
      |
    Need Manager Approval?   (conditional branch point)
      |            \
      |             \ (<=3 days, skip)
    Human Approval    \
      |                \
    Final Decision <---/
      |
     END

Install dependency first:
    pip install langgraph --break-system-packages

Run:
    python3 leave_approval_langgraph.py
"""

from typing import TypedDict, Optional
from langgraph.graph import StateGraph, START, END

AUTO_APPROVE_LIMIT = 3


# 1. State definition — the data that flows through every node

class LeaveState(TypedDict):
    employee_name: str
    leave_days: int
    needs_manager_approval: bool
    manager_decision: Optional[bool]   # True = approved, False = rejected, None = not needed
    status: Optional[str]              # "Approved" / "Rejected"


# ---------------------------------------------------------------------------
# 2. Node functions
# ---------------------------------------------------------------------------
def get_employee_details(state: LeaveState) -> LeaveState:
    """Node: Get Employee Details — collects name + leave days from the employee."""
    name = input("Enter employee name: ").strip()
    while True:
        raw = input("Enter number of leave days: ").strip()
        try:
            days = int(raw)
            if days <= 0:
                print("Leave days must be positive. Try again.")
                continue
            break
        except ValueError:
            print("Please enter a valid whole number.")

    return {**state, "employee_name": name, "leave_days": days}


def check_leave_days(state: LeaveState) -> LeaveState:
    """Node: Check Leave Days — decides whether manager approval is required."""
    needs_approval = state["leave_days"] > AUTO_APPROVE_LIMIT
    print(
        f"\n[Check Leave Days] {state['leave_days']} day(s) requested — "
        f"{'manager approval required' if needs_approval else 'within auto-approval limit'}."
    )
    return {**state, "needs_manager_approval": needs_approval}


def need_manager_approval(state: LeaveState) -> LeaveState:
    """Node: Need Manager Approval? — pass-through node; actual branching
    happens in route_after_check (a conditional edge) below."""
    return state


def human_approval(state: LeaveState) -> LeaveState:
    """Node: Human Approval — asks the manager for a yes/no decision.
    Only reached when leave_days > AUTO_APPROVE_LIMIT."""
    while True:
        resp = input(
            f"[Human Approval] Manager, approve {state['employee_name']}'s "
            f"{state['leave_days']}-day leave request? (yes/no): "
        ).strip().lower()
        if resp in ("yes", "y"):
            return {**state, "manager_decision": True}
        if resp in ("no", "n"):
            return {**state, "manager_decision": False}
        print("Please answer 'yes' or 'no'.")


def final_decision(state: LeaveState) -> LeaveState:
    """Node: Final Decision — computes the final Approved/Rejected status."""
    if not state["needs_manager_approval"]:
        status = "Approved"
    else:
        status = "Approved" if state.get("manager_decision") else "Rejected"

    print("\n----- Leave Request Summary -----")
    print(f"Employee     : {state['employee_name']}")
    print(f"Leave Days   : {state['leave_days']}")
    print(f"Final Status : {status}")
    print("----------------------------------")

    return {**state, "status": status}


# ---------------------------------------------------------------------------
# 3. Routing function for the conditional edge
# ---------------------------------------------------------------------------
def route_after_check(state: LeaveState) -> str:
    """Used as the conditional edge out of 'need_manager_approval'."""
    return "human_approval" if state["needs_manager_approval"] else "final_decision"


# ---------------------------------------------------------------------------
# 4. Build the graph
# ---------------------------------------------------------------------------
def build_graph():
    graph = StateGraph(LeaveState)

    graph.add_node("get_employee_details", get_employee_details)
    graph.add_node("check_leave_days", check_leave_days)
    graph.add_node("need_manager_approval", need_manager_approval)
    graph.add_node("human_approval", human_approval)
    graph.add_node("final_decision", final_decision)

    graph.add_edge(START, "get_employee_details")
    graph.add_edge("get_employee_details", "check_leave_days")
    graph.add_edge("check_leave_days", "need_manager_approval")

    graph.add_conditional_edges(
        "need_manager_approval",
        route_after_check,
        {
            "human_approval": "human_approval",
            "final_decision": "final_decision",
        },
    )

    graph.add_edge("human_approval", "final_decision")
    graph.add_edge("final_decision", END)

    return graph.compile()


# ---------------------------------------------------------------------------
# 5. Run it
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    app = build_graph()

    initial_state: LeaveState = {
        "employee_name": "",
        "leave_days": 0,
        "needs_manager_approval": False,
        "manager_decision": None,
        "status": None,
    }

    result = app.invoke(initial_state)
    # result now contains the full final state, including "status"
