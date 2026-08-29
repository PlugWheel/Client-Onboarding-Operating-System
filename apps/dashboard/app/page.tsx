import { getOnboardings } from "./db";
import { DashboardClient } from "./dashboard-client";

export const dynamic = "force-dynamic";

export default async function Dashboard() {
  return <DashboardClient onboardings={await getOnboardings()} />;
}
