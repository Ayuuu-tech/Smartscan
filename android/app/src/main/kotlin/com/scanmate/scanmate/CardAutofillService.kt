package com.scanmate.scanmate

import android.app.assist.AssistStructure
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.view.View
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import org.json.JSONArray
import java.util.Locale

/**
 * Serves the vault's payment cards to credit-card forms in other apps
 * (checkout pages, browsers). Only reads the CVV-free mirror written by
 * [AutofillCardStore]; we never capture what users type elsewhere.
 */
@RequiresApi(Build.VERSION_CODES.O)
class CardAutofillService : AutofillService() {

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback,
    ) {
        val structure = request.fillContexts.lastOrNull()?.structure
        if (structure == null) {
            callback.onSuccess(null)
            return
        }

        val fields = CardFields()
        for (i in 0 until structure.windowNodeCount) {
            collectFields(structure.getWindowNodeAt(i).rootViewNode, fields)
        }
        // Only respond to forms that actually ask for a card number.
        if (fields.number == null) {
            callback.onSuccess(null)
            return
        }

        val cards = try {
            JSONArray(AutofillCardStore.read(applicationContext))
        } catch (_: Exception) {
            JSONArray()
        }

        val response = FillResponse.Builder()
        var datasets = 0
        for (i in 0 until cards.length()) {
            val card = cards.optJSONObject(i) ?: continue
            val number = card.optString("number")
            if (number.length < 12) continue

            val label = "${card.optString("title").ifEmpty { "Card" }} •••• ${number.takeLast(4)}"
            val presentation =
                RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
                    setTextViewText(android.R.id.text1, label)
                }

            val dataset = Dataset.Builder()
            dataset.setValue(fields.number!!, AutofillValue.forText(number), presentation)
            fields.name?.let {
                val name = card.optString("name")
                if (name.isNotEmpty()) {
                    dataset.setValue(it, AutofillValue.forText(name), presentation)
                }
            }
            val mm = card.optInt("expiryMonth", 0)
            val yy = card.optInt("expiryYear", 0)
            if (mm in 1..12 && yy > 0) {
                val mmText = String.format(Locale.US, "%02d", mm)
                fields.expMonth?.let {
                    dataset.setValue(it, AutofillValue.forText(mmText), presentation)
                }
                fields.expYear?.let {
                    dataset.setValue(it, AutofillValue.forText(yy.toString()), presentation)
                }
                fields.expDate?.let {
                    dataset.setValue(
                        it,
                        AutofillValue.forText("$mmText/${String.format(Locale.US, "%02d", yy % 100)}"),
                        presentation,
                    )
                }
            }
            response.addDataset(dataset.build())
            datasets++
        }

        // FillResponse.build() throws if it's completely empty.
        callback.onSuccess(if (datasets > 0) response.build() else null)
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        // Intentionally not capturing card data typed in other apps.
        callback.onSuccess()
    }

    private class CardFields {
        var number: AutofillId? = null
        var name: AutofillId? = null
        var expMonth: AutofillId? = null
        var expYear: AutofillId? = null
        var expDate: AutofillId? = null
    }

    private fun collectFields(node: AssistStructure.ViewNode, fields: CardFields) {
        val id = node.autofillId
        if (id != null) {
            val hints = node.autofillHints?.map { it.lowercase(Locale.US) } ?: emptyList()
            // Fall back to view id / hint text when the app didn't declare
            // autofill hints (very common on Indian checkout pages).
            val freeText = listOfNotNull(node.idEntry, node.hint)
                .joinToString(" ")
                .lowercase(Locale.US)

            when {
                View.AUTOFILL_HINT_CREDIT_CARD_NUMBER in hints ||
                    (freeText.contains("card") && freeText.contains("number")) ->
                    if (fields.number == null) fields.number = id

                View.AUTOFILL_HINT_CREDIT_CARD_EXPIRATION_MONTH in hints ||
                    freeText.contains("expmonth") || freeText.contains("expirymonth") ->
                    if (fields.expMonth == null) fields.expMonth = id

                View.AUTOFILL_HINT_CREDIT_CARD_EXPIRATION_YEAR in hints ||
                    freeText.contains("expyear") || freeText.contains("expiryyear") ->
                    if (fields.expYear == null) fields.expYear = id

                View.AUTOFILL_HINT_CREDIT_CARD_EXPIRATION_DATE in hints ||
                    freeText.contains("expiry") || freeText.contains("mm/yy") ->
                    if (fields.expDate == null) fields.expDate = id

                hints.any { it.contains("cardholder") } ||
                    (freeText.contains("card") && freeText.contains("holder")) ||
                    freeText.contains("nameoncard") ->
                    if (fields.name == null) fields.name = id
            }
        }
        for (i in 0 until node.childCount) {
            collectFields(node.getChildAt(i), fields)
        }
    }
}
