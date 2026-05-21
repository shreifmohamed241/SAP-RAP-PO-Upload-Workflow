@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PO Upload Items Interface'

define view entity ZI_PUR_UPLOAD_I
  as select from zpur_upload_i
  association to parent ZI_PUR_UPLOAD_H as _Header
    on $projection.UploadUuid = _Header.UploadUuid
{
  key upload_uuid   as UploadUuid,
  key item_no       as ItemNo,
      vendor        as Vendor,
      material      as Material,
      short_text    as ShortText,
      quantity      as Quantity,
      unit          as Unit,
      price         as Price,
      currency      as Currency,
      delivery_date as DeliveryDate,
      plant         as Plant,
      storage_loc   as StorageLoc,
      po_item_no    as PoItemNo,
      item_status   as ItemStatus,
      _Header
}

