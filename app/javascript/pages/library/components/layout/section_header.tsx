interface SectionHeaderProps {
  title: string
  action?: React.ReactNode
}

export default function SectionHeader({ title, action }: SectionHeaderProps) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h2
          className="font-medium tracking-wider text-white capitalize"
          style={{
            fontSize: "1.4vw",
            lineHeight: "1.25vw",
          }}
        >
          {title}
        </h2>
      </div>

      {action}
    </div>
  )
}
