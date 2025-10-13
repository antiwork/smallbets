interface SectionHeaderProps {
  eyebrow: string
  title: string
  action?: React.ReactNode
}

export default function SectionHeader({ eyebrow, title, action }: SectionHeaderProps) {
  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-2 px-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <p className="text-sm font-semibold uppercase tracking-wide text-slate-500">{eyebrow}</p>
        <h2 className="text-2xl font-semibold text-slate-900">{title}</h2>
      </div>

      {action}
    </div>
  )
}
