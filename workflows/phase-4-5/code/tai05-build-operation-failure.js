const input = $input.first().json;
const issueStatus = String(input.issueStatus ?? '');
const revokeStatus = String(input.revokeStatus ?? '');
const resolutionStatus = String(input.resolutionStatus ?? '');

const failureCode =
  issueStatus ||
  revokeStatus ||
  resolutionStatus ||
  'SECURE_INVITATION_OPERATION_FAILED';

const messages = {
  ACTIVE_INVITATION_EXISTS:
    'برای این ارزیابی یک دعوت فعال وجود دارد. ابتدا همان لینک را استفاده یا دعوت را باطل کنید.',
  INVITATION_ALREADY_CLAIMED:
    'این دعوت قبلاً برای شروع مصاحبه استفاده شده است.',
  PHASE3_HANDOFF_NOT_ELIGIBLE:
    'ارزیابی کامل و قابل استفاده‌ای برای صدور دعوت پیدا نشد.',
  INVITATION_NOT_FOUND:
    'دعوت موردنظر پیدا نشد.',
  CLAIMED_INVITATION_NOT_REVOKED:
    'دعوت استفاده‌شده قابل ابطال نیست.',
  EXPIRED_INVITATION_NOT_REVOKED:
    'دعوت منقضی‌شده نیازی به ابطال ندارد.',
};

const message =
  messages[failureCode] ??
  'عملیات دعوت امن تکمیل نشد. جزئیات خصوصی در خروجی نمایش داده نمی‌شود.';

return [
  {
    json: {
      success: false,
      failureCode,
      retryable: false,
      output: `<p>${message}</p><p><strong>کد وضعیت:</strong> ${failureCode}</p>`,
    },
  },
];
