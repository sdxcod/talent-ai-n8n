const item = $input.first();

const requestId = String(
  item.json.requestId ?? ''
).trim().toLowerCase();

const positionCode = String(
  item.json.positionCode ?? ''
).trim().toUpperCase();

const targetGradeCode = String(
  item.json.targetGradeCode ?? ''
).trim().toUpperCase();

const jobDescription = String(
  item.json.jobDescription ?? ''
).trim();

const resume = item.binary?.resume;

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const allowedGrades = new Set([
  'JUNIOR',
  'MID',
  'SENIOR'
]);

if (requestId && !uuidPattern.test(requestId)) {
  throw new Error(
    'INVALID_REQUEST_ID: requestId must be an RFC 4122 UUID.'
  );
}

if (positionCode !== 'JAVA_BACKEND') {
  throw new Error(
    `Unsupported position code: ${positionCode || 'empty'}`
  );
}

if (!allowedGrades.has(targetGradeCode)) {
  throw new Error(
    `Unsupported target grade: ${targetGradeCode || 'empty'}`
  );
}

if (jobDescription.length < 30) {
  throw new Error(
    'Job description must contain at least 30 characters'
  );
}

if (!resume) {
  throw new Error(
    'A resume PDF file is required'
  );
}

const fileName = String(
  resume.fileName ?? ''
).trim();

const mimeType = String(
  resume.mimeType ?? ''
).trim().toLowerCase();

if (!fileName.toLowerCase().endsWith('.pdf')) {
  throw new Error(
    `Only PDF resumes are supported: ${fileName || 'unknown file'}`
  );
}

if (
  mimeType &&
  mimeType !== 'application/pdf' &&
  mimeType !== 'application/octet-stream'
) {
  throw new Error(
    `Unsupported resume MIME type: ${mimeType}`
  );
}

return [
  {
    json: {
      requestId,
      positionCode,
      targetGradeCode,
      jobDescription,
      sourceFileName: fileName,
      sourceMimeType: mimeType || 'application/pdf'
    },
    binary: item.binary
  }
];
