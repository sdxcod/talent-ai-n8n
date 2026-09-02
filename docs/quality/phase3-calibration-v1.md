# TalentAI Phase 3 scoring calibration v1

## Purpose

This suite verifies that the deterministic Grade Engine remains explainable at
the frozen `JAVA_BACKEND` Grade Guide version `1.0.0`. It adds no scoring
capability and does not tune thresholds automatically.

## Automated coverage

Run:

```bash
node scripts/test-phase3-calibration.mjs
```

The suite executes the **actual JavaScript stored in the committed n8n
`Calculate Deterministic Grade` node**, rather than a copied implementation.
It covers Junior, Mid and Senior profiles, exact decision thresholds, a result
below the Senior threshold, mandatory-floor failure, low-evidence and
overstatement review, contradictory claims, warnings, confidence gating,
evidence traceability and 25 identical deterministic repetitions per case.

The canonical machine-readable fixtures are in
`demo/phase3/calibration-cases.json`. All profiles are synthetic.

## Human comparison protocol

Before changing a threshold, two Java interviewers independently review every
fixture without seeing the AI decision. For each case they record:

| Field | Allowed value |
|---|---|
| Human decision | `MEETS_TARGET`, `BELOW_TARGET`, `REVIEW_REQUIRED` |
| Confidence | `HIGH`, `MEDIUM`, `LOW` |
| Evidence defect | none, missing, contradictory, overstated |
| Mandatory-floor defect | dimension code or none |
| Comment | concise explanation |

Disagreement between reviewers is resolved in a short calibration meeting and
the adjudicated result is committed as a new fixture revision. Candidate names
or real resumes must not be committed.

## Threshold change gate

Do not change `30`, `50`, or `70` because of a single LLM run. A threshold
change requires all of the following:

1. at least two independent human reviewers;
2. a versioned, non-sensitive calibration dataset;
3. a documented pattern of disagreement across at least three cases;
4. confirmation that the problem is not an Evidence or Confidence defect;
5. a new Grade Guide version and regression run against the previous version.

## Interpretation

- LLM repeatability is measured separately from deterministic-engine stability.
- A positive score without traceable Evidence is invalid input, not a scoring
  disagreement.
- `LOW` confidence on a target-required dimension produces
  `REVIEW_REQUIRED` under Guide `1.0.0`.
- Warnings are retained but do not alone override a decision; Confidence and
  deterministic review reasons control that outcome.
- The implemented enum is `REVIEW_REQUIRED`; `REQUIRES_REVIEW` is not valid.
