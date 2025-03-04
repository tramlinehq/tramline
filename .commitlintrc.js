export default {
  extends: ["@commitlint/config-conventional"],
  rules: {
    /**
     * reduce header max length violation to a warning
     */
    "header-max-length": [1, "always", 72]
  }
}
