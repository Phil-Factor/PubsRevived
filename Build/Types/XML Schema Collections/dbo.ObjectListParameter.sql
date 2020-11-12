CREATE XML SCHEMA COLLECTION [dbo].[ObjectListParameter] 
AS N'<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <xsd:element name="Object">
    <xsd:simpleType>
      <xsd:list itemType="xsd:string" />
    </xsd:simpleType>
  </xsd:element>
</xsd:schema>'
GO
