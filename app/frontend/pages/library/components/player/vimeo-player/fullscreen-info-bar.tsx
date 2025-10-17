import { DownloadMenu } from "./download-menu"

interface FullscreenInfoBarProps {
  title: string
  creator: string
  vimeoId: string
  downloadPath?: string
}

export function FullscreenInfoBar({
  title,
  creator,
  vimeoId,
  downloadPath,
}: FullscreenInfoBarProps) {
  return (
    <div className="flex h-[var(--bar-h)] items-center justify-between border-t border-white/10 bg-black/95 px-4 pb-[calc(env(safe-area-inset-bottom))] text-white md:px-6">
      <div className="min-w-0 pr-3">
        <h2 className="truncate text-lg font-medium">{title}</h2>
        <p className="truncate text-sm text-gray-400">{creator}</p>
      </div>
      <DownloadMenu
        vimeoId={vimeoId}
        downloadPath={downloadPath}
        title={title}
      />
    </div>
  )
}
