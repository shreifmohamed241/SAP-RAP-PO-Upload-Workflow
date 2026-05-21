@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PO Upload Items Projection'
@Metadata.allowExtensions: true

define view entity ZC_PUR_UPLOAD_I
  as projection on ZI_PUR_UPLOAD_I
{
  key UploadUuid,
  key ItemNo,
      Vendor,
      Material,
      ShortText,
      Quantity,
      Unit,
      Price,
      Currency,
      DeliveryDate,
      Plant,
      StorageLoc,
      PoItemNo,
      ItemStatus,
      _Header : redirected to parent ZC_PUR_UPLOAD_H
}

