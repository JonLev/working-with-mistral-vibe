// server.js — createServer(): wire the tools and resource onto a low-level
// SDK Server. The low-level API is deliberate: tools are declared with plain
// JSON Schema (the MCP wire format), so zod stays out of the dependency tree
// and @modelcontextprotocol/sdk is the only runtime dependency.

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
  ErrorCode,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';
import { loadReference, getReferenceRaw, SERVER_NAME, SERVER_VERSION } from './lib/reference.js';
import { searchGuideTool, readPageTool, listPagesTool } from './lib/tools.js';

const INSTRUCTIONS = [
  `This server serves the working-with-mistral-vibe guide (a community guide for Mistral AI's Vibe products) from bundled, generated content.`,
  '',
  'Workflow:',
  '1. Call search_guide(query) FIRST to find relevant guide pages.',
  '2. Call read_page(path) for a page in full, or read_page(path, section) for one section.',
  '3. When you quote or paraphrase guide content, cite the guide path (e.g. guide/core/architecture.md).',
  '',
  'list_pages() enumerates every page with its description. The file://reference.yaml resource exposes the full generated index.',
].join('\n');

const TOOLS = [
  {
    name: 'search_guide',
    description:
      'Search the working-with-mistral-vibe guide by topic or keyword. Case-insensitive substring match over page titles, descriptions, tags, and heading texts from the generated reference index. Use this FIRST for any Vibe question.',
    inputSchema: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Search query — topic, question, or keyword (e.g. "hooks", "compaction", "skills")',
        },
      },
      required: ['query'],
      additionalProperties: false,
    },
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false },
    handler: ({ query }) => searchGuideTool({ query }),
  },
  {
    name: 'read_page',
    description:
      'Read a bundled guide page (e.g. "guide/core/architecture.md"). With a section anchor, returns only that section: from its heading to the next same-or-higher heading.',
    inputSchema: {
      type: 'object',
      properties: {
        path: {
          type: 'string',
          description: 'Repo-relative page path, as returned by search_guide() or list_pages()',
        },
        section: {
          type: 'string',
          description: 'Optional section heading text (case-insensitive, or its slug), e.g. "1. The master loop"',
        },
      },
      required: ['path'],
      additionalProperties: false,
    },
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false },
    handler: ({ path, section }) => readPageTool({ path, section }),
  },
  {
    name: 'list_pages',
    description:
      'List every page in the working-with-mistral-vibe guide: path, title, and description. Useful for exploring what the guide covers before searching.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
    annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false },
    handler: () => listPagesTool(),
  },
];

export function createServer() {
  const server = new Server(
    { name: SERVER_NAME, version: SERVER_VERSION },
    { instructions: INSTRUCTIONS, capabilities: { tools: {}, resources: {} } },
  );

  try {
    const reference = loadReference();
    process.stderr.write(
      `[${SERVER_NAME}] loaded ${reference.pages.length} pages from content/reference.yaml (index version ${reference.version})\n`,
    );
  } catch (err) {
    process.stderr.write(`[${SERVER_NAME}] warning: failed to load the reference index: ${err}\n`);
  }

  server.setRequestHandler(ListToolsRequestSchema, () => ({
    tools: TOOLS.map(({ handler, ...tool }) => tool),
  }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    const tool = TOOLS.find((t) => t.name === name);
    if (!tool) {
      throw new McpError(ErrorCode.MethodNotFound, `Unknown tool: ${name}`);
    }
    return tool.handler(args ?? {});
  });

  server.setRequestHandler(ListResourcesRequestSchema, () => ({
    resources: [
      {
        uri: 'file://reference.yaml',
        name: 'reference',
        description:
          'The generated machine-readable index of every guide page: path, title, description, tags, and headings with line numbers. Fallback when search_guide() results are insufficient.',
        mimeType: 'text/yaml',
      },
    ],
  }));

  server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
    if (request.params.uri !== 'file://reference.yaml') {
      throw new McpError(ErrorCode.InvalidRequest, `Unknown resource: ${request.params.uri}`);
    }
    return {
      contents: [{ uri: 'file://reference.yaml', mimeType: 'text/yaml', text: getReferenceRaw() }],
    };
  });

  return server;
}
