BEGIN;

INSERT INTO talentai.grade_guide
(
    position_code,
    guide_version,
    guide_schema_version,
    status,
    guide,
    activated_at
)
VALUES
(
    'JAVA_BACKEND',
    '1.0.0',
    '1.0',
    'ACTIVE',
    $$
    {
      "schemaVersion": "1.0",
      "positionCode": "JAVA_BACKEND",
      "guideVersion": "1.0.0",
      "title": "Java Backend Developer",
      "decisionPolicy": {
        "finalGradeAssignedBy": "DETERMINISTIC_ENGINE",
        "llmRole": "EVIDENCE_SCORING_ONLY",
        "unsupportedClaimScore": 0
      },
      "evidencePolicy": {
        "requireEvidenceQuote": true,
        "minimumConfidenceForScoring": "MEDIUM",
        "maximumScoreForIndirectEvidence": 1,
        "missingEvidenceScore": 0
      },
      "scoringScale": [
        {
          "score": 0,
          "code": "NO_EVIDENCE",
          "description": "No relevant evidence is present in the resume."
        },
        {
          "score": 1,
          "code": "LIMITED",
          "description": "The skill is mentioned, but practical ownership or depth is unclear."
        },
        {
          "score": 2,
          "code": "PRACTICAL",
          "description": "Practical use is supported by explicit project or responsibility evidence."
        },
        {
          "score": 3,
          "code": "ADVANCED",
          "description": "Advanced design, troubleshooting, optimization, or ownership is explicit."
        },
        {
          "score": 4,
          "code": "LEADERSHIP",
          "description": "Technical leadership, cross-team influence, or organization-level ownership is explicit."
        }
      ],
      "dimensions": [
        {
          "code": "JAVA_CORE",
          "title": "Core Java and JVM",
          "weight": 25,
          "mandatory": true,
          "criteria": [
            "Java language and standard library",
            "Collections, streams, generics, and concurrency",
            "JVM behavior, profiling, and performance"
          ]
        },
        {
          "code": "SPRING_ECOSYSTEM",
          "title": "Spring Ecosystem",
          "weight": 20,
          "mandatory": true,
          "criteria": [
            "Spring Boot application development",
            "Spring Data and transaction management",
            "Configuration, validation, security, and resilience"
          ]
        },
        {
          "code": "DATABASE",
          "title": "Database and Persistence",
          "weight": 15,
          "mandatory": true,
          "criteria": [
            "Relational data modeling and SQL",
            "JPA or alternative persistence technologies",
            "Transactions, migrations, and query performance"
          ]
        },
        {
          "code": "DISTRIBUTED_SYSTEMS",
          "title": "Distributed Systems and Messaging",
          "weight": 15,
          "mandatory": false,
          "criteria": [
            "Messaging and event-driven systems",
            "Reliability, retries, idempotency, and consistency",
            "Service communication and distributed failure handling"
          ]
        },
        {
          "code": "TESTING",
          "title": "Testing and Quality",
          "weight": 10,
          "mandatory": true,
          "criteria": [
            "Unit and integration testing",
            "Test doubles, containers, and API testing",
            "Quality gates and maintainable test design"
          ]
        },
        {
          "code": "SOFTWARE_ARCHITECTURE",
          "title": "Software Architecture",
          "weight": 10,
          "mandatory": false,
          "criteria": [
            "Modularity and separation of concerns",
            "Architecture trade-offs and design decisions",
            "Domain boundaries and maintainability"
          ]
        },
        {
          "code": "OBSERVABILITY_DEVOPS",
          "title": "Observability and Delivery",
          "weight": 5,
          "mandatory": false,
          "criteria": [
            "Logging, metrics, tracing, and production diagnosis",
            "Containers, deployment, and CI/CD",
            "Operational ownership"
          ]
        }
      ],
      "grades": [
        {
          "code": "JUNIOR",
          "label": "Junior",
          "minimumOverallScore": 30,
          "minimumDimensionLevels": {
            "JAVA_CORE": 1,
            "SPRING_ECOSYSTEM": 1
          }
        },
        {
          "code": "MID",
          "label": "Mid-level",
          "minimumOverallScore": 50,
          "minimumDimensionLevels": {
            "JAVA_CORE": 2,
            "SPRING_ECOSYSTEM": 2,
            "DATABASE": 2,
            "TESTING": 1
          }
        },
        {
          "code": "SENIOR",
          "label": "Senior",
          "minimumOverallScore": 70,
          "minimumDimensionLevels": {
            "JAVA_CORE": 3,
            "SPRING_ECOSYSTEM": 3,
            "DATABASE": 3,
            "DISTRIBUTED_SYSTEMS": 2,
            "TESTING": 2,
            "SOFTWARE_ARCHITECTURE": 2
          }
        }
      ]
    }
    $$::jsonb,
    now()
)
ON CONFLICT (position_code, guide_version) DO NOTHING;

COMMIT;
