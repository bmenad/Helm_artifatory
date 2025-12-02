jq -r '
  group_by(.spec.project) |
  map({
    project: .[0].spec.project,
    applications: map(.metadata.name)
  }) |
  .[]
' apps.json

jq -r '
  group_by(.spec.project) |
  map({
    project: .[0].spec.project,
    applications: map(.metadata.name)
  }) |
  map(select(.project | contains("nprod"))) |
  .[]
' apps.json

jq -r '
  group_by(.spec.project) |
  map({project:.[0].spec.project, applications: map(.metadata.name)}) |
  map(select(.project | contains("nprod"))) |
  .[] |
  "Projet: \(.project)\nApplications:\n" +
  ( .applications[] | "  - " + . ) + "\n"
' apps.json
