import type { QuartzComponentConstructor } from "@quartz-community/types";

export interface RepoLinkOptions {
  url: string;
  label?: string;
}

declare const RepoLink: QuartzComponentConstructor;

export { RepoLink };
