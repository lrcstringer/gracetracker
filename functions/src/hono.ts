import { trpcServer } from '@hono/trpc-server';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { appRouter } from './trpc/app-router';
import { createContext } from './trpc/create-context';

const app = new Hono();

app.use('*', cors({ origin: '*' }));

app.use(
  '/api/trpc/*',
  trpcServer({
    endpoint: '/api/trpc',
    router: appRouter,
    createContext,
  })
);

app.get('/', (c) => c.json({ status: 'ok', message: 'GraceWay API is running' }));

export default app;
