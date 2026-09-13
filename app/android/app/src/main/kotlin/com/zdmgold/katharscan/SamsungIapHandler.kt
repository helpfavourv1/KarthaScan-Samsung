package com.zdmgold.katharscan

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class SamsungIapHandler(private val activity: Activity) {
    private val CHANNEL = "com.zdmgold.katharscan/samsung_iap"
    private var channel: MethodChannel? = null

    fun setup(flutterEngine: FlutterEngine) {
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    try {
                        val iapClass = Class.forName("com.samsung.inapp.IAPHelper")
                        val getInstanceMethod = iapClass.getMethod("getInstance", android.content.Context::class.java)
                        val iapHelper = getInstanceMethod.invoke(null, activity)
                        val setModeMethod = iapClass.getMethod("setOperationMode", Class.forName("com.samsung.inapp.IAPHelper\$OperationMode"))
                        val prodMode = Class.forName("com.samsung.inapp.IAPHelper\$OperationMode").enumConstants.first { it.toString() == "PRODUCTION" }
                        setModeMethod.invoke(iapHelper, prodMode)
                        result.success(true)
                    } catch (e: Exception) { result.error("INIT_FAILED", e.message, null) }
                }
                "purchase" -> {
                    val itemId = call.argument<String>("itemId")
                    if (itemId == null) { result.error("INVALID_ARGS", "Missing itemId", null); return@setMethodCallHandler }
                    try {
                        val iapClass = Class.forName("com.samsung.inapp.IAPHelper")
                        val getInstanceMethod = iapClass.getMethod("getInstance", android.content.Context::class.java)
                        val iapHelper = getInstanceMethod.invoke(null, activity)
                        val startPaymentMethod = iapClass.getMethod("startPaymentActivity", Activity::class.java, Int::class.java, String::class.java, String::class.java)
                        val itemTypeField = iapClass.getField("ITEM_TYPE_NON_CONSUMABLE")
                        val itemType = itemTypeField.get(null)
                        startPaymentMethod.invoke(iapHelper, activity, 1001, itemId, itemType)
                        result.success(true)
                    } catch (e: Exception) { result.error("PURCHASE_FAILED", e.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 1001 && data != null) {
            try {
                val iapClass = Class.forName("com.samsung.inapp.IAPHelper")
                val responseResultField = iapClass.getField("RESPONSE_RESULT")
                val statusCode = data.getIntExtra(responseResultField.name, -1)
                val errorNoneField = iapClass.getField("IAP_ERROR_NONE")
                val errorNone = errorNoneField.getInt(null)
                if (statusCode == errorNone) {
                    val responsePurchaseListField = iapClass.getField("RESPONSE_PURCHASE_LIST")
                    val purchaseList = data.getSerializableExtra(responsePurchaseListField.name) as? ArrayList<*>
                    if (purchaseList != null && purchaseList.isNotEmpty()) {
                        val purchase = purchaseList[0]!!
                        val getPurchaseId = purchase.javaClass.getMethod("getPurchaseId")
                        val getItemId = purchase.javaClass.getMethod("getItemId")
                        val json = JSONObject()
                        json.put("purchaseId", getPurchaseId.invoke(purchase))
                        json.put("itemId", getItemId.invoke(purchase))
                        json.put("status", "purchased")
                        channel?.invokeMethod("onPurchaseUpdate", json.toString())
                    }
                } else {
                    val errorMsgField = iapClass.getField("RESPONSE_ERROR_MSG")
                    val errorMsg = data.getStringExtra(errorMsgField.name) ?: "Unknown error"
                    val json = JSONObject().put("status", "error").put("message", errorMsg)
                    channel?.invokeMethod("onPurchaseUpdate", json.toString())
                }
            } catch (e: Exception) {
                val json = JSONObject().put("status", "error").put("message", e.message)
                channel?.invokeMethod("onPurchaseUpdate", json.toString())
            }
        }
    }
}
