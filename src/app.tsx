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
  Select,
} from "antd";
import "antd/dist/antd.css";

const mainElement = document.createElement("div");
document.body.appendChild(mainElement);

const App = () => {
  const [form] = Form.useForm();
  const [connecting, setConnecting] = useState(false);
  const [loginSuccess, setLoginSuccess] = useState(false);
  const [userInfo, setUserInfo] = useState({ address: "", playerName: "" });
  const [snipeModeOn, setSnipeModeOn] = useState(false);
  const [afkModeOn, setAFKModeOn] = useState(false);
  const [keysToBuy, setKeysToBuy] = useState(1.1);
  const [secondsToBuy, setSecondsToBuy] = useState(15);
  const [ethToSpend, setEthToSpend] = useState(1.0);
  const [gasToSpend, setGasToSpend] = useState(5);
  const [selectedChest, setSelectedChest] = useState(
    "0x3718B1a1Bae216055adb1330E142546A9b11Fb33"
  );

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
      ipcRenderer.send("enableStartSnipe", { ethToSpend, gasToSpend, selectedChest });
      if (!snipeModeOn) {
        message.success("Start round sniper on!");
      } else {
        message.success("Start round sniper off!");
      }
    },
    [ethToSpend, gasToSpend, snipeModeOn, selectedChest]
  );

  const startAFKMode = useCallback(
    (e) => {
      setAFKModeOn(!afkModeOn);
      ipcRenderer.send("enableAFKMode", { keysToBuy, secondsToBuy, selectedChest });
      if (!afkModeOn) {
        message.success("AFK mode on!");
      } else {
        message.success("AFK mode off!");
      }
    },
    [keysToBuy, secondsToBuy, afkModeOn, selectedChest]
  );

  const logout = useCallback((e) => {
    settings.set("settings", {});
    setLoginSuccess(false);
    setUserInfo({ address: "", playerName: "" });
  }, []);

  useEffect(() => {
    ipcRenderer.on("loginSuccess", (_, arg) => {
      message.success(`Private key loaded!`);
      setLoginSuccess(true);
      setUserInfo(arg);
      setConnecting(false);
    });
    ipcRenderer.on("loginFailed", () => {
      message.error("Failed to save private key, please ensure it is valid!");
      setLoginSuccess(false);
      setUserInfo({ address: "", playerName: "" });
      setConnecting(false);
    });
    ipcRenderer.on("logs", (e, msg) => {
      console.log(msg);
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
                  <h3>User Info</h3>
                  <p>Address: {userInfo.address}</p>
                  <p>Player Name: {userInfo?.playerName ? userInfo?.playerName : "A random pirate"}</p>

                  <p>Select a chest:</p>
                  <Select
                    value={selectedChest}
                    onChange={(e) => setSelectedChest(e)}
                    style={{ width: "100%", marginBottom: 25 }}
                  >
                    <Select.Option
                      key="0x3718B1a1Bae216055adb1330E142546A9b11Fb33"
                      value="0x3718B1a1Bae216055adb1330E142546A9b11Fb33"
                    >
                      Jungle (0x3718B1a1Bae216055adb1330E142546A9b11Fb33)
                    </Select.Option>
                    <Select.Option
                      key="0xc9bEf8927c9765f2B458F83a1B84914E3B6d2f15"
                      value="0xc9bEf8927c9765f2B458F83a1B84914E3B6d2f15"
                    >
                      Wault (0xc9bEf8927c9765f2B458F83a1B84914E3B6d2f15)
                    </Select.Option>
                    <Select.Option
                      key="0x4C4608550fbECEf7f969b7659c356E0ADf786aDE"
                      value="0x4C4608550fbECEf7f969b7659c356E0ADf786aDE"
                    >
                      Ape (0x4C4608550fbECEf7f969b7659c356E0ADf786aDE)
                    </Select.Option>
                  </Select>

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
