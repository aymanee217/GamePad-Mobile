package com.example.gamepad_mobile

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHidDevice
import android.bluetooth.BluetoothHidDeviceCallback
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class BluetoothHidPlugin(private val activity: Activity) : MethodCallHandler {

    companion object {
        private const val TAG = "BTHidPlugin"
        private const val CHANNEL = "bluetooth_hid"
    }

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var hidDevice: BluetoothHidDevice? = null
    private var isRegistered = false
    private var callback: BluetoothHidDeviceCallback? = null
    private var channel: MethodChannel? = null
    private var connectedDevice: BluetoothDevice? = null

    // Standard gamepad HID report descriptor (9 bytes per report):
    //   [0-1] buttons (16 bits), [2] hat switch, [3-6] LX/LY/RX/RY (signed 8bit),
    //   [7-8] L2/R2 (unsigned 8bit)
    private val hidDescriptor = byteArrayOf(
        0x05, 0x01,          // Usage Page (Generic Desktop)
        0x09, 0x05,          // Usage (Game Pad)
        0xA1, 0x01,          // Collection (Application)
        0x05, 0x09,          //   Usage Page (Button)
        0x19, 0x01,          //   Usage Minimum (1)
        0x29, 0x10,          //   Usage Maximum (16)
        0x15, 0x00,          //   Logical Minimum (0)
        0x25, 0x01,          //   Logical Maximum (1)
        0x75, 0x01,          //   Report Size (1)
        0x95, 0x10,          //   Report Count (16)
        0x81, 0x02,          //   Input (Data,Var,Abs)
        0x05, 0x01,          //   Usage Page (Generic Desktop)
        0x09, 0x39,          //   Usage (Hat Switch)
        0x15, 0x00,          //   Logical Minimum (0)
        0x25, 0x07,          //   Logical Maximum (7)
        0x35, 0x00,          //   Physical Minimum (0)
        0x46, 0x3B.toByte(), 0x01, // Physical Maximum (315)
        0x65, 0x14,          //   Unit (Degrees)
        0x75, 0x04,          //   Report Size (4)
        0x95, 0x01,          //   Report Count (1)
        0x81, 0x42,          //   Input (Data,Var,Abs,Null)
        0x75, 0x01,          //   Report Size (1)
        0x95, 0x04,          //   Report Count (4)
        0x81, 0x01,          //   Input (Const,Array,Abs)
        0x05, 0x01,          //   Usage Page (Generic Desktop)
        0x09, 0x30,          //   Usage (X)
        0x09, 0x31,          //   Usage (Y)
        0x09, 0x32,          //   Usage (Z)
        0x09, 0x35,          //   Usage (Rz)
        0x15, 0x81.toByte(), //   Logical Minimum (-127)
        0x25, 0x7F,          //   Logical Maximum (127)
        0x75, 0x08,          //   Report Size (8)
        0x95, 0x04,          //   Report Count (4)
        0x81, 0x02,          //   Input (Data,Var,Abs)
        0x09, 0x33,          //   Usage (Rx)
        0x09, 0x34,          //   Usage (Ry)
        0x15, 0x00,          //   Logical Minimum (0)
        0x26, 0xFF.toByte(), 0x00, // Logical Maximum (255)
        0x75, 0x08,          //   Report Size (8)
        0x95, 0x02,          //   Report Count (2)
        0x81, 0x02,          //   Input (Data,Var,Abs)
        0xC0                 // End Collection
    )

    fun registerWith(flutterEngine: FlutterEngine) {
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "init" -> initHid(result)
            "sendReport" -> {
                val data = call.argument<ByteArray>("data")
                sendReport(data, result)
            }
            "disconnect" -> disconnect(result)
            "isSupported" -> isSupported(result)
            else -> result.notImplemented()
        }
    }

    private fun isSupported(result: Result) {
        val supported = try {
            val bm = activity.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            val ba = bm?.adapter
            ba != null && ba.isEnabled &&
                activity.packageManager.hasSystemFeature("android.hardware.bluetooth")
        } catch (_: Exception) { false }
        result.success(supported)
    }

    private fun initHid(result: Result) {
        if (isRegistered) {
            result.success(true)
            return
        }

        val bm = activity.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bm?.adapter

        if (bluetoothAdapter == null) {
            result.error("NO_BT", "Bluetooth not supported", null)
            return
        }
        if (!bluetoothAdapter!!.isEnabled) {
            result.error("BT_OFF", "Please turn on Bluetooth", null)
            return
        }

        bluetoothAdapter?.getProfileProxy(activity,
            object : BluetoothProfile.ServiceListener {
                override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                    if (profile == BluetoothProfile.HID_DEVICE) {
                        hidDevice = proxy as BluetoothHidDevice
                        registerApp(result)
                    } else {
                        result.error("NO_HID", "HID Device profile unavailable", null)
                    }
                }

                override fun onServiceDisconnected(profile: Int) {
                    hidDevice = null
                    isRegistered = false
                }
            },
            BluetoothProfile.HID_DEVICE
        )
    }

    private fun registerApp(result: Result) {
        val device = hidDevice ?: run {
            result.error("NO_PROXY", "HID device proxy not available", null)
            return
        }

        callback = object : BluetoothHidDeviceCallback() {
            override fun onAppStatusChanged(plugged: Boolean, errorCode: Int) {
                if (plugged) {
                    isRegistered = true
                    Log.i(TAG, "HID app registered successfully")
                    channel?.invokeMethod("onReady", null)
                    result.success(true)
                } else {
                    isRegistered = false
                    val msg = when (errorCode) {
                        BluetoothHidDevice.ERROR_RSP_INVALID_PARAM -> "Invalid parameters"
                        BluetoothHidDevice.ERROR_RSP_INVALID_RPT_ID -> "Invalid report ID"
                        BluetoothHidDevice.ERROR_RSP_UNKNOWN -> "Unknown error"
                        else -> "Error code $errorCode"
                    }
                    Log.e(TAG, "HID registration failed: $msg")
                    result.error("REGISTER_FAIL", msg, null)
                }
            }

            override fun onConnectionStateChanged(device: BluetoothDevice?, state: Int) {
                connectedDevice = device
                val stateStr = when (state) {
                    BluetoothProfile.STATE_CONNECTED -> "connected"
                    BluetoothProfile.STATE_DISCONNECTED -> "disconnected"
                    BluetoothProfile.STATE_CONNECTING -> "connecting"
                    BluetoothProfile.STATE_DISCONNECTING -> "disconnecting"
                    else -> "unknown"
                }
                Log.i(TAG, "Connection: $stateStr")
                channel?.invokeMethod("onConnectionState", mapOf(
                    "state" to stateStr,
                    "device" to (device?.name ?: "")
                ))
            }

            override fun onGetReport(reportType: Byte, reportId: Byte, bufferSize: Int) {
                // Host requested a report — respond with current state (not needed for input-only)
            }

            override fun onSetReport(reportType: Byte, reportId: Byte, data: ByteArray?) {
                // Host sent a report (e.g., LED control, rumble) — ignore for now
            }
        }

        try {
            device.registerApp(hidDescriptor, null, null, callback!!)
        } catch (e: SecurityException) {
            Log.e(TAG, "Missing BLUETOOTH_PRIVILEGED permission", e)
            result.error("NO_PRIVILEGE",
                "Bluetooth HID requires system-level permission. " +
                "Try: adb shell appops grant com.example.gamepad_mobile BLUETOOTH_PRIVILEGED", null)
        } catch (e: Exception) {
            Log.e(TAG, "registerApp failed", e)
            result.error("REGISTER_EXCEPTION", e.message, null)
        }
    }

    private fun sendReport(data: ByteArray?, result: Result) {
        if (data == null) {
            result.error("INVALID", "No data", null); return
        }
        if (!isRegistered) {
            result.error("NOT_REGISTERED", "HID app not registered", null); return
        }
        try {
            val ok = hidDevice?.sendReport(BluetoothHidDevice.REPORT_TYPE_INPUT, 0.toByte(), data)
            if (ok == true) {
                result.success(true)
            } else {
                result.error("SEND_FAIL", "sendReport returned false", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "sendReport failed", e)
            result.error("SEND_EXCEPTION", e.message, null)
        }
    }

    private fun disconnect(result: Result) {
        try {
            hidDevice?.unregisterApp()
            bluetoothAdapter?.closeProfileProxy(BluetoothProfile.HID_DEVICE, hidDevice)
        } catch (_: Exception) {}
        hidDevice = null
        isRegistered = false
        connectedDevice = null
        result.success(true)
    }
}
