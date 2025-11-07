import type { CSSProperties } from "react"
import {
  CircleCheckIcon,
  InfoIcon,
  Loader2Icon,
  OctagonXIcon,
  TriangleAlertIcon,
} from "lucide-react"
import { Toaster as Sonner, type ToasterProps } from "sonner"

const style: CSSProperties = { zIndex: 2147483647 }

function Toaster(props: ToasterProps) {
  return (
    <Sonner
      theme="light"
      className="toaster group"
      icons={{
        success: <CircleCheckIcon className="size-4" />,
        info: <InfoIcon className="size-4" />,
        warning: <TriangleAlertIcon className="size-4" />,
        error: <OctagonXIcon className="size-4" />,
        loading: <Loader2Icon className="size-4 animate-spin" />,
      }}
      toastOptions={{
        style: {
          backgroundColor: "#fff",
          color: "#0f172a",
          border: "1px solid rgba(15, 23, 42, 0.08)",
          backdropFilter: "none",
          boxShadow:
            "0px 10px 40px rgba(15, 23, 42, 0.08), 0px 4px 16px rgba(15, 23, 42, 0.04)",
        },
      }}
      position="top-center"
      style={style}
      {...props}
    />
  )
}

export { Toaster }
