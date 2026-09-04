const assessment = $input.first().json;

const score = Number(assessment.score?.overall ?? 0);
const minimumRequired = Number(
  assessment.score?.minimumRequired ?? 0
);
const mandatoryPassed =
  assessment.score?.mandatoryDimensionsMet === true;
const decision = assessment.decision ?? 'UNKNOWN';
const fullName =
  assessment.candidate?.fullName ?? 'Unknown candidate';
const positionCode =
  assessment.assessmentContext?.positionCode ?? '';
const targetGradeCode =
  assessment.assessmentContext?.targetGradeCode ?? '';
const requestId =
  assessment.execution?.requestId ?? assessment.requestId ?? '';
const attemptCount = Number(
  assessment.execution?.attemptCount ?? 1
);
const replayed =
  assessment.execution?.replayed === true ||
  assessment.metadata?.replayed === true;

const assessmentId = String(assessment.assessmentId ?? '').trim();
const extractionId = String(assessment.extractionId ?? '').trim();
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const invitationEligible =
  decision === 'MEETS_TARGET' && uuidPattern.test(extractionId);
const invitationPath = invitationEligible
  ? `/form/talentai-secure-interview-invitation?action=ISSUE&extractionId=${encodeURIComponent(extractionId)}&ttlMinutes=2880`
  : null;

const escapeHtml = (value) =>
  String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

const detail = (label, value, ltr = false) =>
  `<p><strong>${escapeHtml(label)}:</strong> ` +
  `<span${ltr ? ' dir="ltr"' : ''}>${escapeHtml(value)}</span></p>`;

const output = [
  '<p><strong>TalentAI assessment completed.</strong></p>',
  detail('Request ID', requestId, true),
  detail('Attempt', attemptCount, true),
  detail('Replayed', replayed ? 'YES' : 'NO', true),
  detail('Candidate', fullName),
  detail('Position', positionCode, true),
  detail('Target Grade', targetGradeCode, true),
  detail('Overall Score', `${score} / 100`, true),
  detail('Required Score', `${minimumRequired} / 100`, true),
  detail(
    'Mandatory Requirements',
    mandatoryPassed ? 'PASSED' : 'NOT PASSED',
    true
  ),
  detail('Decision', decision, true),
  detail('Assessment ID', assessmentId, true),
  detail('Extraction ID', extractionId, true),
  detail('Grade Guide', assessment.gradeGuide?.version, true),
  detail('Model', assessment.metadata?.scoringModel, true),
  invitationEligible
    ? `<p><a href="${escapeHtml(invitationPath)}" target="_blank" rel="noopener noreferrer">صدور دعوت امن مصاحبه</a></p>`
    : '',
  decision === 'REVIEW_REQUIRED'
    ? '<p>این ارزیابی پیش از صدور دعوت به بررسی HR نیاز دارد.</p>'
    : '',
].join('');

return [
  {
    json: {
      output,
      requestId,
      attemptCount,
      replayed,
      assessmentId,
      extractionId,
      candidateName: fullName,
      positionCode,
      targetGradeCode,
      overallScore: score,
      minimumRequiredScore: minimumRequired,
      thresholdMet: assessment.score?.thresholdMet,
      mandatoryDimensionsMet: mandatoryPassed,
      decision,
      invitationEligible,
      invitationPath,
      gradeGuideVersion: assessment.gradeGuide?.version,
      scoringModel: assessment.metadata?.scoringModel,
      createdAt: assessment.metadata?.createdAt,
    },
  },
];
