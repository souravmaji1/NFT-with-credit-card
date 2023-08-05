import Stripe from "stripe";
import { buffer } from "micro";
import { NextApiRequest, NextApiResponse } from "next";
import { ThirdwebSDK } from "@thirdweb-dev/sdk";
import { ethers } from "ethers";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY as string, {
  apiVersion: "2022-11-15",
});

const webhookSecret = process.env.WEBHOOK_SECRET_KEY as string;

export const config = {
  api: {
    bodyParser: false,
  },
};

const handler = async (req: NextApiRequest, res: NextApiResponse) => {
  const buf = await buffer(req);
  const sig = req.headers["stripe-signature"];

  const sdk = ThirdwebSDK.fromPrivateKey(
    process.env.PRIVATE_KEY as string,
    "mumbai"
  );

 
  const nftCollection = await sdk.getContract("0xe39aEBC9Ae55b5B84EDA1932416cEcc49692837e");
 
  let event;

  if (buf && sig) {
    try {
      event = stripe.webhooks.constructEvent(buf, sig, webhookSecret);
    } catch (err) {
      return res.status(400).send(`Webhook Error: ${(err as Error).message}`);
    }

    const data = JSON.parse(String(buf));

    if (event.type === "payment_intent.succeeded") {
      const paymentMethod = event.data.object as any;
      const domain = paymentMethod.metadata.domain;
      const category = paymentMethod.metadata.category;
    

      const tx = await nftCollection.call(
        "register", 
       [domain, 
        category],
        {
          value: ethers.utils.parseEther("0.01"),
        }
      );

      const txReceipt = await tx.wait();
      
      
      console.log('Mint transaction successful!', tx);


      console.log(txReceipt);

      console.log(
        `PaymentIntent was successfull for: ${data.data.object.amount}`
      );
    }
  }
  return res.json({ received: true });
};

export default handler;
