# Foundry Template [![Open in Gitpod][gitpod-badge]][gitpod] [![Github Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] [![License: MIT][license-badge]][license]

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
participant p as project
participant c as cep contract
participant e as evaluation contract
participant g as governor contract
participant r as registry contract
participant d as DAO participant
participant t as Treasury

p->>r : register project, return projectId
p->>c : deploy evaluation contract
c->>c: create evaluation pool
note over p, d: project create impact IRL
d->>c: call evaluate impact function, deposit some token
c->>c: attest evaluation
c->>g: create proposal
d->> g: vote for proposal
g->g: voting pepriods
alt proposal has passed
g->>d: funds will back
else voting has not passed
g->>t: token will send to treasury
end
```
