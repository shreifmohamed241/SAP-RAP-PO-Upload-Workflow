@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PO Upload Header Interface'

define root view entity ZI_PUR_UPLOAD_H
  as select from zpur_upload_h
  composition [0..*] of ZI_PUR_UPLOAD_I as _Items
{
  key upload_uuid   as UploadUuid,
      upload_no     as UploadNo,
      uploaded_by   as UploadedBy,
      upload_date   as UploadDate,
      upload_time   as UploadTime,
      file_name     as FileName,
      status        as Status,
      manager       as Manager,
      reject_reason as RejectReason,
      po_number     as PoNumber,

      @Semantics.largeObject: {
        mimeType: 'MimeType',
        fileName: 'FileName',
        acceptableMimeTypes: ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
        contentDispositionPreference: #ATTACHMENT
      }
      file_content as FileContent,

      @Semantics.mimeType: true
      mime_type    as MimeType,

      _Items
}

