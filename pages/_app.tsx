import React from "react";
import type { AppProps } from "next/app";
import { ChainId, ThirdwebProvider, magicLink, metamaskWallet} from "@thirdweb-dev/react";
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';

const darkTheme = createTheme({
  typography: {
    fontFamily: 'monospace'
  },
  palette: {
    mode: 'dark',
  },
});


// This is the chain your dApp will work on.
const activeChain = ChainId.Mumbai;



// Array of wallet connectors you want to use for your dApp.


function MyApp({ Component, pageProps }: AppProps) {
  return (
    <ThirdwebProvider
    activeChain={activeChain}
    supportedWallets={[
      metamaskWallet(),
      magicLink({
        apiKey: "pk_live_A2A7EA6BCCD0ED73",
      })
    ]}
    clientId="753a68dac4ad23e4724462f7cf8e9d07"
  >
   <ThemeProvider theme={darkTheme}>
      <Component {...pageProps} />
      </ThemeProvider>
     
    </ThirdwebProvider>
  );
}

export default MyApp;
