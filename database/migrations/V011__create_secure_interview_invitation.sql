BEGIN;

CREATE TABLE IF NOT EXISTS talentai.technical_interview_invitation
(
    id                                  UUID                     NOT NULL DEFAULT gen_random_uuid(),
    contract_version                    VARCHAR(20)              NOT NULL,
    request_id                          UUID                     NOT NULL,
    assessment_id                       UUID                     NOT NULL,
    extraction_id                       UUID                     NOT NULL,
    token_hash                          CHAR(64)                 NOT NULL,
    status                              VARCHAR(20)              NOT NULL DEFAULT 'ISSUED',
    issue_count                         INTEGER                  NOT NULL DEFAULT 1,
    issued_by_workflow_execution_id     VARCHAR(100)             NOT NULL,
    claimed_by_workflow_execution_id    VARCHAR(100),
    revoked_by_workflow_execution_id    VARCHAR(100),
    issued_at                           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    expires_at                          TIMESTAMP WITH TIME ZONE NOT NULL,
    claimed_at                          TIMESTAMP WITH TIME ZONE,
    revoked_at                          TIMESTAMP WITH TIME ZONE,
    updated_at                          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),

    CONSTRAINT technical_interview_invitation_pkey
        PRIMARY KEY (id),

    CONSTRAINT uq_technical_interview_invitation_handoff
        UNIQUE (contract_version, request_id, assessment_id),

    CONSTRAINT uq_technical_interview_invitation_token_hash
        UNIQUE (token_hash),

    CONSTRAINT ck_technical_interview_invitation_contract
        CHECK (contract_version = '1.0.0'),

    CONSTRAINT ck_technical_interview_invitation_token_hash
        CHECK (token_hash ~ '^[0-9a-f]{64}$'),

    CONSTRAINT ck_technical_interview_invitation_status
        CHECK (status IN ('ISSUED', 'CLAIMED', 'REVOKED', 'EXPIRED')),

    CONSTRAINT ck_technical_interview_invitation_issue_count
        CHECK (issue_count >= 1),

    CONSTRAINT ck_technical_interview_invitation_timestamps
        CHECK (
            expires_at > issued_at
            AND updated_at >= issued_at
            AND (claimed_at IS NULL OR claimed_at >= issued_at)
            AND (revoked_at IS NULL OR revoked_at >= issued_at)
        ),

    CONSTRAINT ck_technical_interview_invitation_lifecycle
        CHECK (
            (
                status = 'ISSUED'
                AND claimed_by_workflow_execution_id IS NULL
                AND claimed_at IS NULL
                AND revoked_by_workflow_execution_id IS NULL
                AND revoked_at IS NULL
            )
            OR
            (
                status = 'CLAIMED'
                AND claimed_by_workflow_execution_id IS NOT NULL
                AND claimed_at IS NOT NULL
                AND revoked_by_workflow_execution_id IS NULL
                AND revoked_at IS NULL
            )
            OR
            (
                status = 'REVOKED'
                AND claimed_by_workflow_execution_id IS NULL
                AND claimed_at IS NULL
                AND revoked_by_workflow_execution_id IS NOT NULL
                AND revoked_at IS NOT NULL
            )
            OR
            (
                status = 'EXPIRED'
                AND claimed_by_workflow_execution_id IS NULL
                AND claimed_at IS NULL
                AND revoked_by_workflow_execution_id IS NULL
                AND revoked_at IS NULL
            )
        )
);

CREATE INDEX IF NOT EXISTS ix_technical_interview_invitation_status_expiry
    ON talentai.technical_interview_invitation (status, expires_at);

CREATE INDEX IF NOT EXISTS ix_technical_interview_invitation_phase3_ids
    ON talentai.technical_interview_invitation
       (request_id, assessment_id, extraction_id);

GRANT SELECT, INSERT, UPDATE
ON TABLE talentai.technical_interview_invitation
TO talentai_app;

COMMIT;
