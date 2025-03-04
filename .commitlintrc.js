export default {
  extends: ["@commitlint/config-conventional"],
  rules: {
    /**
     * allowed scopes when committing
     *
     * e.g.
     *
     * - fix(feat): add jira integration
     * - feat(chore): update the specs
     *
     */
    "scope-enum": [2, "always", ["feat", "chore", "security"]],
    /**
     * reduce header max length violation to a warning
     */
    "header-max-length": [1, "always", 72]
  }
}
