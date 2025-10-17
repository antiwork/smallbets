interface SectionHeaderProps {
  title: string
  action?: React.ReactNode
}

export default function SectionHeader({ title, action }: SectionHeaderProps) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h2 className="text-[clamp(1rem,1.2vw,1.5rem)] leading-tight font-medium tracking-wider text-white capitalize select-none">
          {title}
        </h2>
      </div>

      {action}
    </div>
  )
}
