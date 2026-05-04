import type { Metadata } from "next";
import "./styles.css";

export const metadata: Metadata = {
  title: "Cloud Superbrain",
  description: "Phase 1 developer platform foundation",
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
