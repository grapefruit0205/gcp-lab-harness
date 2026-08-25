def redact($value; $mask):
  if $mask == true then
    "<redacted>"
  elif (($mask | type) == "object" and ($value | type) == "object") then
    reduce ($mask | keys_unsorted[]) as $key
      ($value; .[$key] = redact(.[$key]; $mask[$key]))
  elif (($mask | type) == "array" and ($value | type) == "array") then
    [range(0; $value | length) as $index |
      redact($value[$index]; ($mask[$index] // false))]
  else
    $value
  end;

del(.variables, .planned_values, .prior_state)
| .resource_changes = [
    .resource_changes[]? |
    .change.before = redact(.change.before; (.change.before_sensitive // false)) |
    .change.after = redact(.change.after; (.change.after_sensitive // false))
  ]
| .output_changes = ((.output_changes // {}) | with_entries(
    .value.before = redact(.value.before; (.value.before_sensitive // false)) |
    .value.after = redact(.value.after; (.value.after_sensitive // false))
  ))
