export type Onboarding = {
  id: string;
  displayId: string;
  initials: string;
  client: string;
  engagement: string;
  owner: string;
  stage: string;
  progress: number;
  blocker: string;
  age: string;
  sla: "Healthy" | "At risk" | "Breached";
  accent: string;
  resources: Array<{ provider: string; status: string; url: string | null; lastError: string | null }>;
  requirements: Array<{ key: string; label: string; status: string }>;
  intakeToken: string | null;
  kickoff: { startsAt: string; meetingUrl: string | null } | null;
  tasks: Array<{ title: string; status: string; role: string }>;
  timeline: Array<{ title: string; detail: string | null; occurredAt: string }>;
};

export const onboardings: Onboarding[] = [
  { id: "OB-1048", displayId: "OB-1048", initials: "NS", client: "Northstar", engagement: "Growth engagement", owner: "Olivia Park", stage: "Awaiting client", progress: 68, blocker: "Brand asset pack", age: "18h", sla: "Healthy", accent: "#cf5c36", resources: [], requirements: [], intakeToken: null, kickoff: null, tasks: [], timeline: [] },
  { id: "OB-1047", displayId: "OB-1047", initials: "FA", client: "Fieldstone", engagement: "Finance transformation", owner: "Jon Bell", stage: "Commercial hold", progress: 22, blocker: "Deposit pending", age: "3d", sla: "At risk", accent: "#507463", resources: [], requirements: [], intakeToken: null, kickoff: null, tasks: [], timeline: [] },
  { id: "OB-1044", displayId: "OB-1044", initials: "AT", client: "Arcwell", engagement: "Recruiting partnership", owner: "Olivia Park", stage: "Ready for kickoff", progress: 91, blocker: "None", age: "6d", sla: "Breached", accent: "#334e68", resources: [], requirements: [], intakeToken: null, kickoff: null, tasks: [], timeline: [] },
  { id: "OB-1043", displayId: "OB-1043", initials: "HM", client: "Hearth & Moss", engagement: "Brand transformation", owner: "Jon Bell", stage: "Provisioning", progress: 45, blocker: "Drive folder retry", age: "1d", sla: "Healthy", accent: "#a27b5c", resources: [], requirements: [], intakeToken: null, kickoff: null, tasks: [], timeline: [] },
];
