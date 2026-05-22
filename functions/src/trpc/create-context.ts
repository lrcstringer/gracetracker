import { initTRPC, TRPCError } from '@trpc/server';
import type { FetchCreateContextFnOptions } from '@trpc/server/adapters/fetch';
import superjson from 'superjson';
import { auth } from '../lib/admin';

export const createContext = async (opts: FetchCreateContextFnOptions) => {
  const authHeader = opts.req.headers.get('authorization');
  let userId: string | null = null;

  let displayName: string | null = null;

  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    try {
      const decoded = await auth.verifyIdToken(token);
      userId = decoded.uid;
      displayName = (decoded.name as string | undefined) ?? null;
    } catch {
      // Token invalid or expired — userId stays null
      // protectedProcedure will throw UNAUTHORIZED
    }
  }

  return { req: opts.req, userId, displayName };
};

export type Context = Awaited<ReturnType<typeof createContext>>;

const t = initTRPC.context<Context>().create({ transformer: superjson });

export const createTRPCRouter = t.router;
export const publicProcedure = t.procedure;
export const protectedProcedure = t.procedure.use(async ({ ctx, next }) => {
  if (!ctx.userId) {
    throw new TRPCError({ code: 'UNAUTHORIZED', message: 'Authentication required' });
  }
  return next({ ctx: { ...ctx, userId: ctx.userId } });
});
