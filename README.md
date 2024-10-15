# Impact Evaluation Service(IES) [![Open in Gitpod][gitpod-badge]][gitpod] [![Github Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] [![License: MIT][license-badge]][license]

[gitpod]: https://gitpod.io/#https://github.com/tnkshuuhei/ie-dao
[gitpod-badge]: https://img.shields.io/badge/Gitpod-Open%20in%20Gitpod-FFB45B?logo=gitpod
[gha]: https://github.com/tnkshuuhei/ie-dao/actions
[gha-badge]: https://github.com/tnkshuuhei/ie-dao/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: https://opensource.org/licenses/MIT
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg

![impactevaluationprotocol](https://github.com/user-attachments/assets/2fe7d216-18e7-402a-a503-6a4b91a2e04a)

```mermaid
sequenceDiagram
participant p as Project
participant m as Market
participant c as Core contract
participant g as Governor contract
participant e as Evaluator
participant v as Voter
participant t as Treasury

p->>c : register project
p->>m : create impact
e->>m : capture impact
e->>c : create impact report, deposit token
c->>g : create proposal, transfer deposited token
v->>g : vote for proposal
alt proposal has passed
g->>e: funds will back
c->>e: mint hypercerts
else voting has not passed
g->>t: token will send to treasury
end
note over p, t: the end of the year or quoter
c->>c: create splits based on the balance of Hypercerts fraction
c->>e: reward
```
