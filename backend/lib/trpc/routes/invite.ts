import * as z from "zod";

import { createTRPCRouter, publicProcedure, protectedProcedure } from "../create-context";
import { dbGet } from "../../db";

interface Circle {
  id: string;
  name: string;
  description: string;
  creatorId: string;
  inviteCode: string;
  memberCount: number;
  createdAt: string;
}

export const inviteRouter = createTRPCRouter({
  resolveInviteCode: publicProcedure
    .input(z.object({ inviteCode: z.string() }))
    .query(async ({ input }) => {
      const code = input.inviteCode.toUpperCase();
      const circleId = await dbGet<string>(`invite:${code}`);

      if (!circleId) {
        return {
          inviteCode: input.inviteCode,
          circleName: null as string | null,
          isValid: false,
        };
      }

      const circle = await dbGet<Circle>(`circle:${circleId}`);
      return {
        inviteCode: input.inviteCode,
        circleName: circle?.name ?? null,
        isValid: !!circle,
      };
    }),

  generateShareLink: protectedProcedure
    .input(
      z.object({
        circleId: z.string(),
      }),
    )
    .mutation(async ({ ctx, input }) => {
      const circle = await dbGet<Circle>(`circle:${input.circleId}`);
      const inviteCode = circle?.inviteCode ?? "";
      return {
        shareUrl: `https://graceway.faith/join/${inviteCode}`,
        inviteCode,
      };
    }),
});
