const input = $input.first().json;
const extractionId =
  typeof input.extractionId === 'string'
    ? input.extractionId.trim()
    : '';

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

if (!uuidPattern.test(extractionId)) {
  throw new Error(
    'INVALID_EXTRACTION_ID: extractionId must be a valid UUID.'
  );
}

return [{ json: { extractionId } }];
