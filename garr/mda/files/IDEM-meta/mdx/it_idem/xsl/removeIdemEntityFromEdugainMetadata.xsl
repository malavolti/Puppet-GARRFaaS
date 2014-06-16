<!-- 
   Carriage Return ==> <xsl:text>&#10;</xsl:text>
   Tab             ==> <xsl:text>&#x09;</xsl:text>
   -->
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
                xmlns:hoksso="urn:oasis:names:tc:SAML:2.0:profiles:holder-of-key:SSO:browser"
                xmlns:idpdisc="urn:oasis:names:tc:SAML:profiles:SSO:idp-discovery-protocol"
                xmlns:init="urn:oasis:names:tc:SAML:profiles:SSO:request-init"
                xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
                xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion" 
                xmlns:mdui="urn:oasis:names:tc:SAML:metadata:ui" 
                xmlns:mdrpi="urn:oasis:names:tc:SAML:metadata:rpi"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:xenc="http://www.w3.org/2001/04/xmlenc#"
                xmlns:shibmd="urn:mace:shibboleth:metadata:1.0"
                xmlns:saml1md="urn:mace:shibboleth:metadata:1.0">

   <xsl:output method="xml" omit-xml-declaration="no" encoding="UTF-8" indent="yes"/>

    <!-- Identity template : copy all text nodes, elements and attributes -->   
    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()" />
        </xsl:copy>
    </xsl:template>

    <xsl:template match="/*/*[contains(@ID, 'IDEM-EDUGAIN')]" />
</xsl:stylesheet>
