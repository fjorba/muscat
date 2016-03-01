<?xml version="1.0" encoding="UTF-8"?>

<!-- Version: 2016-03-01 -->

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:marc="http://www.loc.gov/MARC21/slim">
    <xsl:output method="text" encoding="UTF-8" indent="no" omit-xml-declaration="yes" />
    <xsl:strip-space elements="*"/>

    <xsl:template match="/">
        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template name="string-replace-all">
      <xsl:param name="text" />
      <xsl:param name="replace" />
      <xsl:param name="by" />
      <xsl:choose>
        <xsl:when test="contains($text, $replace)">
          <xsl:value-of select="substring-before($text,$replace)" />
          <xsl:value-of select="$by" />
          <xsl:call-template name="string-replace-all">
            <xsl:with-param name="text"
             select="substring-after($text,$replace)" />
            <xsl:with-param name="replace" select="$replace" />
            <xsl:with-param name="by" select="$by" />
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$text" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <xsl:template match="marc:record">
      <xsl:text>=000  </xsl:text>
        <xsl:value-of select="marc:leader"/>
        <xsl:text>&#xa;</xsl:text>
        <xsl:apply-templates select="marc:datafield|marc:controlfield"/>
    </xsl:template>
    
    <xsl:template match="marc:controlfield">
		 <xsl:if test="@tag='001'">
			<xsl:text>=</xsl:text>
			<xsl:value-of select="@tag"/>
			<xsl:text>  </xsl:text>
			<xsl:value-of select="."/>
			<xsl:text>&#xa;</xsl:text>
		 </xsl:if>
    </xsl:template>

    <xsl:template match="marc:datafield">
		 <xsl:if test="
			 @tag='024' or 
			 @tag='100' or 
			 @tag='375' or 
			 @tag='400' or 
			 @tag='550' or 
			 @tag='551'">
			 <xsl:text>=</xsl:text>
 			 <xsl:choose>
				<xsl:when test="@tag='550'">
					<xsl:value-of select="374"/>
				</xsl:when>

				<xsl:otherwise >
					<xsl:value-of select="@tag"/>
				</xsl:otherwise>
			</xsl:choose>
        <xsl:text>  </xsl:text>
        <xsl:value-of select="translate(@ind1,' ','#')"/>
        <xsl:value-of select="translate(@ind2,' ','#')"/>
        <xsl:apply-templates select="marc:subfield"/>
		  <xsl:text>&#xa;</xsl:text>
		</xsl:if>
	</xsl:template>
    <xsl:template match="marc:subfield">
        <xsl:text>$</xsl:text>
        <xsl:value-of select="@code"/>
		  <xsl:variable name="newtext">
  			  <xsl:choose>
				  <xsl:when test="../@tag='024' and @code='a' and contains(current(), 'd-nb')">
					<xsl:call-template name="string-replace-all">
						<xsl:with-param name="text" select="substring-after(text(), 'gnd/')" />
						<xsl:with-param name="replace" select="'$'" />
						<xsl:with-param name="by" select="'_DOLLAR_'" />
					</xsl:call-template>
					</xsl:when>
	 				<xsl:when test="../@tag='024' and @code='2' and contains(current(), 'uri')">
					<xsl:call-template name="string-replace-all">
						<xsl:with-param name="text" select="'DNB'" />
						<xsl:with-param name="replace" select="'$'" />
						<xsl:with-param name="by" select="'_DOLLAR_'" />
					</xsl:call-template>
				</xsl:when>

				<xsl:when test="../@tag='375' and @code='a'">
					<xsl:choose>
						<xsl:when test="text()=1">
							<xsl:value-of select="'male'"/>
							</xsl:when>
							<xsl:when test="text()=2">
							<xsl:value-of select="'female'"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="'unknown'"/>
						</xsl:otherwise>
				</xsl:choose>


				</xsl:when>


				<xsl:otherwise>
					<xsl:call-template name="string-replace-all">
						<xsl:with-param name="text" select="current()" />
						<xsl:with-param name="replace" select="'$'" />
						<xsl:with-param name="by" select="'_DOLLAR_'" />
						</xsl:call-template>
				</xsl:otherwise>
			</xsl:choose>
        </xsl:variable>
       <xsl:value-of select="$newtext"/>
	 </xsl:template>
</xsl:stylesheet>
 
