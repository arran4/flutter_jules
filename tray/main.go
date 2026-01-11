package main

import (
	"io/ioutil"
	"log"

	"github.com/energye/systray"
)

const (
	ipcFilePath = "tray.ipc"
)

func main() {
	systray.Run(onReady, onExit)
}

func onReady() {
	systray.SetTitle("Jules")
	systray.SetTooltip("Jules")

	mShow := systray.AddMenuItem("Show", "Show the main window")
	mQuit := systray.AddMenuItem("Quit", "Quit the application")

	mShow.Click(func() {
		sendCommand("show")
	})

	mQuit.Click(func() {
		systray.Quit()
	})
}

func onExit() {
	// Clean up here
}

func sendCommand(command string) {
	err := ioutil.WriteFile(ipcFilePath, []byte(command), 0644)
	if err != nil {
		log.Fatalf("failed to write command to IPC file: %v", err)
	}
}
