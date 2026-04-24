import * as z from 'zod';
import { createTRPCRouter, publicProcedure, protectedProcedure } from '../create-context';
import { inviteCodesCol, circlesCol } from '../../lib/firestore';

export const inviteRouter = createTRPCRouter({
  resolveInviteCode: publicProcedure
    .input(z.object({ inviteCode: z.string() }))
    .query(async ({ input }) => {
      const code = input.inviteCode.toUpperCase();
      const snap = await inviteCodesCol().doc(code).get();

      if (!snap.exists) {
        return { inviteCode: input.inviteCode, circleName: null as string | null, isValid: false };
      }

      const data = snap.data()!;
      return {
        inviteCode: input.inviteCode,
        circleName: data.circleName as string,
        isValid: true,
      };
    }),

  generateShareLink: protectedProcedure
    .input(z.object({ circleId: z.string() }))
    .mutation(async ({ input }) => {
      const snap = await circlesCol().doc(input.circleId).get();
      const inviteCode = (snap.data()?.inviteCode as string) ?? '';
      return {
        shareUrl: `https://graceway.faith/join/${inviteCode}`,
        inviteCode,
      };
    }),
});
