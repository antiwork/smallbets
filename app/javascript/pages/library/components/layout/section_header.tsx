interface SectionHeaderProps {
  title: string
  action?: React.ReactNode
}

export default function SectionHeader({ title, action }: SectionHeaderProps) {
  return (
    <div className="flex max-w-5xl flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h2 className="text-xl font-medium tracking-wider capitalize">{title}</h2>
      </div>

      {action}
    </div>
  )
}
