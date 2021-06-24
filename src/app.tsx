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
  Checkbox,
} from "antd";
import "antd/dist/antd.css";

const mainElement = document.createElement("div");
document.body.appendChild(mainElement);

const App = () => {
  const [form] = Form.useForm();
  const [connecting, setConnecting] = useState(false);
  const [loginSuccess, setLoginSuccess] = useState(false);

  const login = useCallback((e) => {
    const newSettings = {
      ...e,
    };
    settings.set("settings", newSettings);
    setConnecting(true);
  }, []);

  const startBot = useCallback((e) => {
    if (e.startMode) {
      ipcRenderer.send("enableStartSnipe", e);
    } 
    if (e.afkMode) {
      ipcRenderer.send("enableAFKMode", e);
    }
  }, []);

  useEffect(() => {
    ipcRenderer.on("loginSuccess", () => {
      message.success("Private key saved!");
      setLoginSuccess(true);
      setConnecting(false);
    });
    ipcRenderer.on("loginFailed", () => {
      message.error("Failed to save private key, please ensure it is valid!");
      setLoginSuccess(false);
      setConnecting(false);
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
              <Form form={form} onFinish={startBot}>
                <Divider>Bot Configuration</Divider>

                <Form.Item label="Round Start Sniper" name="startMode">
                  <Checkbox>Deactivated</Checkbox>
                </Form.Item>

                <Form.Item label="AFK mode" name="afkMode">
                  <Checkbox>Deactivated</Checkbox>
                </Form.Item>

                <Button loading={connecting} type="primary" htmlType="submit">
                  Save Bot Settings
                </Button>
              </Form>
            )}
          </Col>
        </Row>
      </Layout.Content>
    </Layout>
  );
};

ReactDom.render(<App />, mainElement);
