BEGIN;

GRANT USAGE ON SCHEMA talentai TO talentai_app;

GRANT SELECT, INSERT
ON TABLE talentai.resume_extraction
TO talentai_app;

GRANT SELECT
ON TABLE talentai.grade_guide
TO talentai_app;

GRANT SELECT, INSERT
ON TABLE talentai.grade_assessment
TO talentai_app;

COMMIT;
