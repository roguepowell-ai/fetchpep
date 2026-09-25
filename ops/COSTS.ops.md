---
authority: claude-proposes
---

# Costs

Ceiling: **£200/month.** Figures below are from planning and are unverified against a bill.

## Setup — about £135 in year one

| Item | |
|---|---|
| Apple Developer | ~£78/yr |
| Google Play Console | ~£20 once |
| Android developer verification | ~£20 once |
| Sprite editor | ~£17 once |
| Android test device | not yet bought |

## Running — about £21–22/month at ten test users

Approved by George at that figure (**D-092**), which makes it the cost of record. Apple
amortised takes it to roughly £28–29/month.

List prices for `europe-west2`, from `infra/dev` as built in PR #20. Not a bill: nothing has
been applied.

| | USD/month |
|---|---|
| e2-small VM | 15.76 |
| Boot disk, 20 GB pd-balanced | ~2.40 |
| Database disk, 20 GB pd-balanced | ~2.40 |
| Cloud NAT gateway, one VM | ~1.02 |
| Cloud NAT external address | ~3.65 |
| NAT data processing | ~0.05–0.15 |
| Snapshots, 14 daily across both disks | ~0.30–0.60 |
| Secret Manager, 8 secrets | 0.00–0.12 |
| Flow logs, firewall logs, Monitoring, IAP, workload identity | inside free tiers |
| **Total** | **~27.5–28, about £21–22** |

**This page used to say £11 and that the VM was 100% of it.** It is about 57%. The rest is
storage and the NAT address, neither of which was counted. Corrected under D-092 rather than
quietly: the earlier figure was an estimate nobody had built against, and the difference is
the sort that turns into a surprise on a bill.

Two of those lines can go together. Mirroring the two container images into Artifact
Registry (**O-78**) lets Private Google Access replace Cloud NAT, removing about $4.70 —
and the VM's only path to the internet with it. That is a new repository and a decision.

Worth knowing rather than changing: co-presence is a premise, not a hypothesis, so the VM
stays.

## Where the risk actually is

**Egress, not compute.** Cloudflare sits in front and R2 has zero egress, which removes the
unbounded line item and also replaces the global load balancer, Cloud CDN and Cloud Armor.

[certain] R2 charges per Class B (read) operation. Bundle sprites into atlases — one
request per creature, not one per frame.

[certain] Cloud Run defaults to 100 max instances, and an instance holding an open
WebSocket bills as active for as long as it is held. Cap it explicitly.

## Controls

1. **Billing kill switch** — Pub/Sub to a Cloud Function that detaches billing. Applied
   before the game goes public; during the pilot, budget alerts are the only guard (D-072).
2. Budget alerts email while the meter still runs. They are a warning, not a control.
3. Spend limits set explicitly on every managed service at creation.
4. `require_partition_filter = TRUE` on every partitioned BigQuery table.
