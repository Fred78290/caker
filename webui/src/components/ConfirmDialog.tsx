import { useRef } from 'react';

interface Props {
  id: string
  title: string
  message: string
  confirmLabel?: string
  confirmClass?: string
  onConfirm: () => void
}

export function ConfirmDialog({
  id,
  title,
  message,
  confirmLabel = 'Delete',
  confirmClass = 'btn-danger',
  onConfirm,
}: Props) {
  const closeRef = useRef<HTMLButtonElement>(null)

  const handleConfirm = () => {
    closeRef.current?.click()
    onConfirm()
  }

  return (
    <div className="modal fade" id={id} tabIndex={-1} aria-hidden="true">
      <div className="modal-dialog">
        <div className="modal-content">
          <div className="modal-header">
            <h5 className="modal-title">{title}</h5>
            <button
              ref={closeRef}
              type="button"
              className="btn-close"
              data-bs-dismiss="modal"
              aria-label="Close"
            />
          </div>
          <div className="modal-body">{message}</div>
          <div className="modal-footer">
            <button
              type="button"
              className="btn btn-secondary"
              data-bs-dismiss="modal"
            >
              Cancel
            </button>
            <button
              type="button"
              className={`btn ${confirmClass}`}
              onClick={handleConfirm}
            >
              {confirmLabel}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

/** Open a Bootstrap modal by id. */
export function openModal(id: string) {
  const el = document.getElementById(id)
  if (el) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const modal = (window as any).bootstrap?.Modal?.getOrCreateInstance(el)
    modal?.show()
  }
}
