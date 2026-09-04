const issued = $input.first().json;
const token = String(issued.invitationToken ?? '').trim().toLowerCase();

if (
  issued.canDeliver !== true ||
  !/^[0-9a-f]{64}$/.test(token) ||
  !issued.invitationId ||
  !issued.expiresAt
) {
  throw new Error('SECURE_INVITATION_RESULT_NOT_AVAILABLE');
}

const invitationPath =
  `/form/talentai-candidate-interview?invitationToken=${encodeURIComponent(token)}`;

const expiresAt = new Date(issued.expiresAt);

if (Number.isNaN(expiresAt.getTime())) {
  throw new Error('SECURE_INVITATION_EXPIRY_INVALID');
}

const output = [
  '<p>دعوت امن مصاحبه با موفقیت صادر شد.</p>',
  `<p><strong>شناسه دعوت:</strong> ${String(issued.invitationId)}</p>`,
  `<p><strong>انقضا:</strong> ${expiresAt.toISOString()}</p>`,
  `<p><strong>دفعات صدور:</strong> ${Number(issued.issueCount)}</p>`,
  `<p><a href="${invitationPath}" target="_blank" rel="noopener noreferrer">باز کردن لینک مصاحبه Candidate</a></p>`,
  '<p>برای ارسال لینک، روی دکمه بالا راست‌کلیک و Copy Link Address را انتخاب کنید.</p>',
].join('');

return [
  {
    json: {
      success: true,
      operation: 'ISSUE',
      invitationId: String(issued.invitationId),
      issueStatus: String(issued.issueStatus),
      issueCount: Number(issued.issueCount),
      expiresAt: expiresAt.toISOString(),
      invitationPath,
      output,
    },
  },
];
