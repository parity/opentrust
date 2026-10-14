import type { LoaderFunctionArgs } from "react-router";
import { redirect } from "react-router";

import styles from "./styles.module.css";

export const loader = async ({ request }: LoaderFunctionArgs) => {
  const url = new URL(request.url);

  if (url.searchParams.get("shop")) {
    throw redirect(`/app?${url.searchParams.toString()}`);
  }

  return null;
};

export default function App() {
  return (
    <div className={styles.index}>
      <div className={styles.content}>
        <h1 className={styles.heading}>OpenTrust for Shopify</h1>
        <p className={styles.text}>
          Check new orders against experiences shared by other Indian merchants. Free.
        </p>
        <p className={styles.text}>Install OpenTrust from your Shopify admin, then open it under Apps.</p>
        <ul className={styles.list}>
          <li><strong>Checks new orders</strong>. When a new order comes in, its phone number is checked with OpenTrust in the background.</li>
          <li><strong>Flags, never blocks</strong>. If other merchants have noted experiences with the number, the order is tagged and annotated for your review. Nothing is cancelled or held.</li>
          <li><strong>Only the phone number</strong>. No names, addresses or order details are sent. Reports are unverified observations, not a finding about anyone.</li>
        </ul>
      </div>
    </div>
  );
}
