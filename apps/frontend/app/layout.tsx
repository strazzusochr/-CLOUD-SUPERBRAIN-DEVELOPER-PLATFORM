import type { Metadata } from "next";
import "./styles.css";

export const metadata: Metadata = {
  title: "Cloud Superbrain — AI Developer Organism Platform",
  description:
    "Open-source, independent, free, multi-cloud AI Developer Organism. Workbench-first platform with a live 3D cortex.",
  icons: {
    icon: "/favicon.ico",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
