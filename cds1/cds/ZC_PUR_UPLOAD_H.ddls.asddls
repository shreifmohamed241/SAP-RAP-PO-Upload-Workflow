@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PO Upload Header Projection'
@Metadata.allowExtensions: true

define root view entity ZC_PUR_UPLOAD_H
  provider contract transactional_query
  as projection on ZI_PUR_UPLOAD_H
{
  key UploadUuid,
      UploadNo,
      UploadedBy,
      UploadDate,
      UploadTime,
      FileName,
      Status,
      Manager,
      RejectReason,
      PoNumber,

      @Semantics.largeObject: {
        mimeType: 'MimeType',
        fileName: 'FileName',
        acceptableMimeTypes: ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
        contentDispositionPreference: #ATTACHMENT
      }
      FileContent,

      @Semantics.mimeType: true
      MimeType,

      _Items : redirected to composition child ZC_PUR_UPLOAD_I
}

