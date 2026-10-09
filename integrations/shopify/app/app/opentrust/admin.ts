// Order updates through the Shopify Admin GraphQL API. `graphql(query, variables)` must return the parsed JSON body
// ({ data, errors }); in the routes that is a thin wrapper around `admin.graphql(...)`.

export type GraphQL = (query: string, variables?: Record<string, unknown>) => Promise<any>;

const TAGS_ADD = `#graphql
  mutation tagsAdd($id: ID!, $tags: [String!]!) {
    tagsAdd(id: $id, tags: $tags) { userErrors { field message } }
  }`;

const GET_NOTE = `#graphql
  query orderNote($id: ID!) { order(id: $id) { note } }`;

const ORDER_UPDATE = `#graphql
  mutation orderUpdate($input: OrderInput!) {
    orderUpdate(input: $input) { userErrors { field message } }
  }`;

function raise(res: any, where: string) {
  const errs = [...(res?.errors ?? []), ...(res?.data?.[where]?.userErrors ?? [])];
  if (errs.length) throw new Error(`Shopify ${where} failed: ${errs.map((e: any) => e.message).join("; ")}`);
}

export async function addTag(graphql: GraphQL, id: string, tag: string) {
  raise(await graphql(TAGS_ADD, { id, tags: [tag] }), "tagsAdd");
}

/** Appends to the order's existing note rather than replacing it. */
export async function appendNote(graphql: GraphQL, id: string, text: string) {
  const current = await graphql(GET_NOTE, { id });
  if (current?.errors?.length) throw new Error(`Shopify order lookup failed: ${current.errors.map((e: any) => e.message).join("; ")}`);
  const existing: string = current?.data?.order?.note ?? "";
  raise(await graphql(ORDER_UPDATE, { input: { id, note: existing ? `${existing}\n\n${text}` : text } }), "orderUpdate");
}
