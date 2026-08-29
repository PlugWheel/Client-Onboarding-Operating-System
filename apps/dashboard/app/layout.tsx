import "@fontsource-variable/manrope";
import "@fontsource/ibm-plex-mono/500.css";
import "./styles.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Relay — Client Onboarding OS",
  description: "From closed-won to kickoff without manual admin.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body suppressHydrationWarning>{children}</body>
    </html>
  );
}
