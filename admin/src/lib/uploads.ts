// Admin upload helpers. Slice 02 (producer images) introduces a single
// flow: admin picks a file → POST /v1/admin/uploads/photo-presign →
// PUT to R2 with the returned URL + headers → use the returned
// `upload_id` as `image_upload_id` on the next admin producer mutation.
//
// Cookie + CSRF auth is handled transparently by the openapi-fetch
// client in `api.ts`; the R2 PUT goes to an external URL and does not
// carry kamos cookies.

import { api } from '@/lib/api';

export interface PresignedUpload {
  uploadId: string;
  uploadUrl: string;
  headers: Record<string, string>;
}

// Allowed image MIME types — must match the backend's
// extensionForContentType in handlers/uploads.go.
const ALLOWED_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);
const MAX_BYTES = 10 * 1024 * 1024;

export class UploadError extends Error {
  code: string;
  constructor(code: string, message: string) {
    super(message);
    this.name = 'UploadError';
    this.code = code;
  }
}

// presignProducerImage runs the full admin upload flow for a producer
// image: presign → PUT to R2 → return the upload_id the caller passes
// as `image_upload_id` on the producer mutation. Throws UploadError
// with a stable `code` for the caller to surface inline.
export async function presignProducerImage(file: File): Promise<string> {
  if (!ALLOWED_TYPES.has(file.type)) {
    throw new UploadError('INVALID_CONTENT_TYPE', 'Image must be JPEG, PNG, or WebP.');
  }
  if (file.size <= 0 || file.size > MAX_BYTES) {
    throw new UploadError('INVALID_BYTE_SIZE', 'Image must be 10 MB or smaller.');
  }
  const { data, error, response } = await api.POST('/v1/admin/uploads/photo-presign', {
    body: {
      content_type: file.type as 'image/jpeg' | 'image/png' | 'image/webp',
      byte_size: file.size,
    },
  });
  if (error || !data) {
    throw new UploadError(`PRESIGN_FAILED_${response.status}`, 'Failed to presign upload.');
  }
  const putRes = await fetch(data.upload_url, {
    method: 'PUT',
    headers: data.headers,
    body: file,
  });
  if (!putRes.ok) {
    throw new UploadError(`R2_PUT_FAILED_${putRes.status}`, 'Failed to upload image to storage.');
  }
  return data.upload_id;
}
