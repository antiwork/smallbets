interface SectionHeaderProps {
  title: string
  action?: React.ReactNode
}

export default function SectionHeader({ title, action }: SectionHeaderProps) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h2 className="text-[1.4vw] leading-[1.25vw] font-medium tracking-wider text-white capitalize">
          {title}
        </h2>
      </div>

      {action}
    </div>
  )
}
