import React, { useCallback, useEffect, useState } from "react";
import ReactDom from "react-dom";
import settings from "electron-settings";
import { ipcRenderer } from "electron";
import {
  Row,
  Col,
  Layout,
  Button,
  Input,
  message,
  Form,
  Divider,
  Slider,
  InputNumber,
} from "antd";
import "antd/dist/antd.css";

const mainElement = document.createElement("div");
document.body.appendChild(mainElement);

const App = () => {
  const [form] = Form.useForm();
  const [connecting, setConnecting] = useState(false);
  const [loginSuccess, setLoginSuccess] = useState(false);
  const [snipeModeOn, setSnipeModeOn] = useState(false);
  const [afkModeOn, setAFKModeOn] = useState(false);
  const [keysToBuy, setKeysToBuy] = useState(1.1);
  const [secondsToBuy, setSecondsToBuy] = useState(15);
  const [ethToSpend, setEthToSpend] = useState(1.0);
  const [gasToSpend, setGasToSpend] = useState(5);

  const login = useCallback((e) => {
    const newSettings = {
      ...e,
    };
    settings.set("settings", newSettings);
    setConnecting(true);
    ipcRenderer.send("login", { password: e.password });
  }, []);

  const startSnipeMode = useCallback(
    (e) => {
      console.log("starting");
      setSnipeModeOn(!snipeModeOn);
      ipcRenderer.send("enableStartSnipe", { ethToSpend, gasToSpend });
      if (!snipeModeOn) {
        message.success("Start round sniper on!");
      } else {
        message.success("Start round sniper off!");
      }
    },
    [ethToSpend, gasToSpend, snipeModeOn]
  );

  const startAFKMode = useCallback(
    (e) => {
      setAFKModeOn(!afkModeOn);
      ipcRenderer.send("enableAFKMode", { keysToBuy, secondsToBuy });
      if (!afkModeOn) {
        message.success("AFK mode on!");
      } else {
        message.success("AFK mode off!");
      }
    },
    [keysToBuy, secondsToBuy, afkModeOn]
  );

  const logout = useCallback((e) => {
    settings.set("settings", {});
    setLoginSuccess(false);
  }, []);

  useEffect(() => {
    ipcRenderer.on("loginSuccess", () => {
      message.success("Private key loaded!");
      setLoginSuccess(true);
      setConnecting(false);
    });
    ipcRenderer.on("loginFailed", () => {
      message.error("Failed to save private key, please ensure it is valid!");
      setLoginSuccess(false);
      setConnecting(false);
    });
    ipcRenderer.on("logs", (e) => {
      console.log(e);
    });

    settings.get("settings").then((e: any) => {
      ipcRenderer.send("login", { password: e.password });
    });
  }, []);

  return (
    <Layout style={{ minHeight: "100vh" }}>
      <Layout.Content>
        <Row style={{ paddingTop: 16 }}>
          <Col span={22} offset={1}>
            <h1>Treasure Key Bot</h1>
            <p>
              This bot has features such as sniping the start of the round, and
              sniping for keys at the end of the round. You will be given the
              choice to set your custom gas fees etc.
            </p>
          </Col>
        </Row>
        <Row gutter={16} style={{ marginLeft: 0, marginRight: 0 }}>
          <Col span={22} offset={1}>
            {!loginSuccess && (
              <Form form={form} onFinish={login}>
                <Divider>Configuration</Divider>

                <Form.Item label="Private Key" name="password" required>
                  <Input.Password placeholder="Password" />
                </Form.Item>
                <Button loading={connecting} type="primary" htmlType="submit">
                  Save
                </Button>
              </Form>
            )}

            {loginSuccess && (
              <div>
                <Divider>Bot Configuration</Divider>
                <br />
                <div>
                  <h3>Round Start Sniper</h3>
                  <p>Number of BNB to spend when sniping</p>
                  <InputNumber
                    value={ethToSpend}
                    onChange={(e) => setEthToSpend(parseFloat(`${e}`) ?? 1)}
                    min={0.0000001}
                    step={0.00001}
                  />
                  <br />
                  <br />
                  <p>Gas price when sniping</p>
                  <InputNumber
                    value={gasToSpend}
                    onChange={(e) => setGasToSpend(parseFloat(`${e}`) ?? 1)}
                    min={5}
                    step={1}
                    max={1000}
                  />
                  <br />
                  <br />
                  <Button
                    loading={connecting}
                    type={"primary"}
                    htmlType="submit"
                    danger={snipeModeOn}
                    onClick={startSnipeMode}
                  >
                    Start Round Sniper
                  </Button>
                </div>
                <br />
                <div>
                  <h3>AFK Mode</h3>
                  <p>Number of keys to buy</p>
                  <Slider
                    value={keysToBuy}
                    onChange={(e) => setKeysToBuy(e)}
                    min={1}
                    max={2}
                    step={0.1}
                  />
                  <br />
                  <p>Buy when timer is left with (seconds)</p>
                  <InputNumber
                    value={secondsToBuy}
                    onChange={(e) => setSecondsToBuy(parseInt(`${e}`) ?? 15)}
                    min={1}
                    step={1}
                  />
                  <br />
                  <br />
                  <Button
                    loading={connecting}
                    type={"primary"}
                    htmlType="submit"
                    danger={afkModeOn}
                    onClick={startAFKMode}
                  >
                    Start AFK Mode
                  </Button>
                </div>
              </div>
            )}
          </Col>
        </Row>

        {loginSuccess && (
          <Row
            gutter={16}
            style={{
              marginLeft: 0,
              marginRight: 0,
              marginTop: 16,
              marginBottom: 32,
            }}
          >
            <Col span={22} offset={1}>
              <h3>Logout</h3>
              <Button
                loading={connecting}
                type={"primary"}
                htmlType="submit"
                onClick={logout}
              >
                Logout
              </Button>
            </Col>
          </Row>
        )}
      </Layout.Content>
    </Layout>
  );
};

ReactDom.render(<App />, mainElement);
