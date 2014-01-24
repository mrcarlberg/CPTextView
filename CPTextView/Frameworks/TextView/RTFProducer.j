/* 
   _RTFProducer.j

   Serialize CPAttributedString to a RTF String 

   Copyright (C) 2014 Daniel Boehringer
   This file is based on the RTFProducer from GNUStep
   (which i co-authored with Fred Kiefer in 1999)
   
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */ 

@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>   // FIXME

var PAPERSIZE = @"PaperSize";
var LEFTMARGIN = @"LeftMargin";
var RIGHTMARGIN = @"RightMargin";
var TOPMARGIN = @"TopMargin";
var BUTTOMMARGIN = @"ButtomMargin";

CPISOLatin1StringEncoding = "CPISOLatin1StringEncoding";

function _points2twips(a) { return (a)*20.0; }


@implementation CPString(Replacing)

- (CPString) stringByReplacingEveryOccurrenceOfString: (CPString)aString withString: (CPString)other
{
    var ret = self;
    var regex = new RegExp(aString, "g");
    ret.replace(regex, other);
    return ret;
}
@end

@implementation RTFProducer:CPObject
{
    CPAttributedString text;
    CPMutableDictionary fontDict;
    CPMutableDictionary colorDict;
    CPDictionary docDict;
    CPMutableArray attachments;

    CPColor fgColor;
    CPColor bgColor;
    CPColor ulColor;
}

+ (CPData)produceRTF: (CPAttributedString) aText documentAttributes: (CPDictionary)dict
{
    var mynew = [self new],
        data;

    data = [[mynew RTFDStringFromAttributedString: aText
	       documentAttributes: dict]
	       dataUsingEncoding: CPISOLatin1StringEncoding];
    return data;
}

- (id)init
{
  /*
   * maintain a dictionary for the used colours
   * (for rtf-header generation)
   */
    colorDict = [CPMutableDictionary new];
  /*
   * maintain a dictionary for the used fonts
   * (for rtf-header generation)
   */
    fontDict = [CPMutableDictionary new];
  
    currentFont = nil;
    fgColor = [CPColor textColor];
    bgColor= [CPColor textBackgroundColor];

    return self;
}

// private stuff follows
- (CPString) fontTable
{
  // write Font Table
    if ([fontDict count])
    {
        var fontlistString = "";
        var fontEnum;
        var currFont;
        var keyArray;

        keyArray = [fontDict allKeys];
        keyArray = [keyArray sortedArrayUsingSelector: @selector(compare:)];

        fontEnum = [keyArray objectEnumerator];
        while ((currFont = [fontEnum nextObject]) != nil)
	{
	    var fontFamily;
	    var detail;

	    if ([currFont isEqualToString: @"Symbol"])
	        fontFamily = @"tech";
	    else if ([currFont isEqualToString: @"Helvetica"])
	        fontFamily = @"swiss";
	    else if ([currFont isEqualToString: @"Courier"])
	        fontFamily = @"modern";
	    else if ([currFont isEqualToString: @"Times"])
	        fontFamily = @"roman";
	    var fontFamily = @"nil";

	    detail = [CPString stringWithFormat: @"%@\\f%@ %@;",
	        [fontDict objectForKey: currFont], fontFamily, currFont];
	    [fontlistString appendString: detail];
	}
        return [CPString stringWithFormat: @"{\\fonttbl%@}\n", fontlistString];
    }
    else
        return @"";
}

- (CPString) colorTable
{
  // write Colour table
    if ([colorDict count])
    {
        var result,
            count = [colorDict count],
            list = [CPMutableArray arrayWithCapacity: count],
            keyEnum = [colorDict keyEnumerator],
            next,
            i;

        while ((next = [keyEnum nextObject]) != nil)
	{
	    var cn = [colorDict objectForKey: next];
	    [list insertObject: next atIndex: [cn intValue]-1];
	}

        result = [CPMutableString stringWithString: @"{\\colortbl;"];
        for (i = 0; i < count; i++)
	{
	    var color = [[list objectAtIndex: i] 
			       colorUsingColorSpaceName: CPCalibratedRGBColorSpace];
	    [result appendString: [CPString stringWithFormat:
					    @"\\red%d\\green%d\\blue%d;",
					 ([color redComponent]*255),
					 ([color greenComponent]*255),
					 ([color blueComponent]*255)]];
	}

        [result appendString: @"}\n"];
        return result;
    }
    else
        return @"";
}

- (CPString) documentAttributes
{
    if (docDict != nil)
    {
        var result,
            detail,
            val,
            num,

        result = [CPMutableString string];

        val = [docDict objectForKey: PAPERSIZE];
        if (val != nil)
        {
	    var size = [val sizeValue];
	    detail = [CPString stringWithFormat: @"\\paperw%d \\paperh%d",
			     _points2twips(size.width), 
			     _points2twips(size.height)];
	    [result appendString: detail];
	}

        num = [docDict objectForKey: LEFTMARGIN];
        if (num != nil)
        {
	    var f = [num floatValue];
	    detail = [CPString stringWithFormat: @"\\margl%d",
			     _points2twips(f)];
	    [result appendString: detail];
	}
        num = [docDict objectForKey: RIGHTMARGIN];
        if (num != nil)
        {
	    var f = [num floatValue];
	    detail = [CPString stringWithFormat: @"\\margr%d",
			     _points2twips(f)];
	    [result appendString: detail];
	}
        num = [docDict objectForKey: TOPMARGIN];
        if (num != nil)
        {
	    var f = [num floatValue];
	    detail = [CPString stringWithFormat: @"\\margt%d",
			     _points2twips(f)];
	    [result appendString: detail];
	}
        num = [docDict objectForKey: BUTTOMMARGIN];
        if (num != nil)
        {
	    var f = [num floatValue];
	    detail = [CPString stringWithFormat: @"\\margb%d",
			     _points2twips(f)];
	    [result appendString: detail];
	}

        return result;
    }
    else
        return @"";
}

- (CPString) headerString
{
    var result;

    result = [CPMutableString stringWithString: @"{\\rtf1\\ansi"];

    [result appendString: [self fontTable]];
    [result appendString: [self colorTable]];
    [result appendString: [self documentAttributes]];

    return result;
}

- (CPString) trailerString
{
    return @"}";
}

- (CPString) fontToken: (CPString) fontName
{
    var fCount = [fontDict objectForKey: fontName];

    if (fCount == nil)
    {
        var count = [fontDict count];
      
        fCount = [CPString stringWithFormat: @"\\f%d", count];
        [fontDict setObject: fCount forKey: fontName];
    }

    return fCount;
}

- (int) numberForColor: (CPColor)color
{
    var cn,
        num = [colorDict objectForKey: color];

    if (num == nil)
    {
        cn = [colorDict count] + 1;
	    
        [colorDict setObject: [CPNumber numberWithInt: cn]
		 forKey: color];
    }
    var cn = [num intValue];

    return cn;
}

- (CPString) paragraphStyle: (CPParagraphStyle) paraStyle
{
    var headerString = [CPMutableString stringWithString:@"\\pard\\plain"],
        twips;

    if (paraStyle == nil)
        return headerString;

    switch ([paraStyle alignment])
    {
        case CPRightTextAlignment:
	    [headerString appendString: @"\\qr"];
	break;
        case CPCenterTextAlignment:
	    [headerString appendString: @"\\qc"];
	break;
        case CPLeftTextAlignment:
	    [headerString appendString: @"\\ql"];
	break;
        case CPJustifiedTextAlignment:
	    [headerString appendString: @"\\qj"];
	break;
        default: break;
    }

    // write first line indent and left indent
    var twips = _points2twips([paraStyle firstLineHeadIndent]);
    if (twips != 0.0)
    {
        [headerString appendString: [CPString stringWithFormat:@"\\fi%d", twips]];
    }
    twips = _points2twips([paraStyle headIndent]);
    if (twips != 0.0)
    {
        [headerString appendString: [CPString stringWithFormat:@"\\li%d", twips]];
    }
    twips = _points2twips([paraStyle tailIndent]);
    if (twips != 0.0)
    {
        [headerString appendString: [CPString stringWithFormat:@"\\ri%d", twips]];
    }
    twips = _points2twips([paraStyle paragraphSpacing]);
    if (twips != 0.0)
    {
        [headerString appendString: [CPString stringWithFormat:@"\\sa%d", twips]];
    }
    twips = _points2twips([paraStyle minimumLineHeight]);
    if (twips != 0.0)
    {
      [headerString appendString: [CPString stringWithFormat:@"\\sl%d", twips]];
    }
    twips = _points2twips([paraStyle maximumLineHeight]);
    if (twips != 0.0)
    {
      [headerString appendString: [CPString stringWithFormat: @"\\sl-%d", twips]];
    }
  // FIXME: Tab definitions are still missing
  
    return headerString;
}

- (CPString) runStringForString: (CPString) substring
		     attributes: (CPDictionary) attributes
		 paragraphStart: (BOOL) first
{
    var result = [CPMutableString stringWithCapacity:[substring length]*2],
        headerString = [CPMutableString stringWithCapacity: 20],
        trailerString = [CPMutableString stringWithCapacity: 20],
        attribEnum,
        currAttrib;
  
    if (first)
    {
        var paraStyle = [attributes objectForKey:CPParagraphStyleAttributeName];
        [headerString appendString: [self paragraphStyle: paraStyle]];
    }

  /*
   * analyze attributes of current run
   *
   * FIXME: All the character attributes should be output relative to the font
   * attributes of the paragraph. So if the paragraph has underline on it should 
   * still be possible to switch it off for some characters, which currently is 
   * not possible.
   */
    attribEnum = [attributes keyEnumerator];
    while ((currAttrib = [attribEnum nextObject]) != nil)
    {
        if ([currAttrib isEqualToString: CPFontAttributeName])
        {
	  /*
	   * handle fonts
	   */
	    var font,
	        fontName,
	        traits;
	  
	    font = [attributes objectForKey: CPFontAttributeName];
	    fontName = [font familyName];
	    traits = [[CPFontManager sharedFontManager] traitsOfFont: font];
	  
	  /*
	   * font name
	   */
	    if (currentFont == nil || 
	        ![fontName isEqualToString: [currentFont familyName]])
	    {
	        [headerString appendString: [self fontToken: fontName]];
	    }
	  /*
	   * font size
	   */
	    if (currentFont == nil || 
	        [font pointSize] != [currentFont pointSize])
	    {
	        var points =[font pointSize]*2,
	            pString;
	      
	        pString = [CPString stringWithFormat: @"\\fs%d", points];
	        [headerString appendString: pString];
	    }
	  /*
	   * font attributes
	   */
	    if (traits & CPItalicFontMask)
	    {
	        [headerString appendString: @"\\i"];
	        [trailerString appendString: @"\\i0"];
	    }
	    if (traits & CPBoldFontMask)
	    {
	        [headerString appendString: @"\\b"];
	        [trailerString appendString: @"\\b0"];
	    }

	    if (first)
	        currentFont = font;
	}
        else if ([currAttrib isEqualToString: CPForegroundColorAttributeName])
        {
	    var color = [attributes objectForKey: CPForegroundColorAttributeName];
	    if (![color isEqual: fgColor])
	    {
	        [headerString appendString: [CPString stringWithFormat:@"\\cf%d", 
						    [self numberForColor: color]]];
	        [trailerString appendString: @"\\cf0"];
	    }
	}
        else if ([currAttrib isEqualToString: CPBackgroundColorAttributeName])
        {
	  var color = [attributes objectForKey: CPBackgroundColorAttributeName];
	  if (![color isEqual: bgColor])
	    {
	        [headerString appendString: [CPString stringWithFormat:@"\\cb%d", 
						    [self numberForColor: color]]];
	        [trailerString appendString: @"\\cb0"];
	    }
	}
        else if ([currAttrib isEqualToString: CPUnderlineStyleAttributeName])
        {
	  [headerString appendString: @"\\ul"];
	  [trailerString appendString: @"\\ulnone"];
	}
        else if ([currAttrib isEqualToString: CPSuperscriptAttributeName])
        {
	    var value = [attributes objectForKey: CPSuperscriptAttributeName],
	        svalue = [value intValue] * 6;
	  
	    if (svalue > 0)
	    {
	        [headerString appendString: [CPString stringWithFormat:@"\\up%d", svalue]];
	        [trailerString appendString: @"\\up0"];
	    }
	    else if (svalue < 0)
	    {
	        [headerString appendString: [CPString stringWithFormat:@"\\dn-%d", svalue]];
	        [trailerString appendString: @"\\dn0"];
	    }
	}
        else if ([currAttrib isEqualToString: CPBaselineOffsetAttributeName])
        {
	    var value = [attributes objectForKey: CPBaselineOffsetAttributeName],
	        svalue = [value floatValue] * 2;
	  
	    if (svalue > 0)
	    {
	        [headerString appendString: [CPString stringWithFormat:@"\\up%d", svalue]];
	        [trailerString appendString: @"\\up0"];
	    }
	    else if (svalue < 0)
	    {
	        [headerString appendString: [CPString stringWithFormat:@"\\dn-%d", svalue]];
	        [trailerString appendString: @"\\dn0"];
	    }
	}
        else if ([currAttrib isEqualToString: CPAttachmentAttributeName])
        {
	}
        else if ([currAttrib isEqualToString: CPLigatureAttributeName])
        {
	}
        else if ([currAttrib isEqualToString: CPKernAttributeName])
        {
	}
    }

    var substring = [substring stringByReplacingString: @"\\" withString: @"\\\\"];
    substring = [substring stringByReplacingString: @"\n" withString: @"\\par\n"];
    substring = [substring stringByReplacingString: @"\t" withString: @"\\tab "];
    substring = [substring stringByReplacingString: @"{" withString: @"\\{"];
    substring = [substring stringByReplacingString: @"}" withString: @"\\}"];
  // FIXME: All characters not in the standard encoding must be
  // replaced by \'xx
  
    if (!first)
    {
        var braces;
      
        if ([headerString length])
	     braces = [CPString stringWithFormat: @"{%@ %@}", headerString, substring];
        else
             braces = substring;
      
      [result appendString: braces];
    }
    else
    {
        var nobraces;

        if ([headerString length])
	    nobraces = [CPString stringWithFormat: @"%@ %@", headerString, substring];
        else
            nobraces = substring;

      
        [result appendString: nobraces];
    }

    return result;
}

- (CPString) bodyString
{
    var string = [text string],
        result = [CPMutableString string],
        loc = 0,
        length = [string length];

    while (loc < length)
    {
      // Range of the current run
       var currRange = CPMakeRange(loc, 0),
      // Range of the current paragraph
        completeRange = [string lineRangeForRange: currRange],
        first = YES;

        while (CPMaxRange(currRange) < CPMaxRange(completeRange))  // save all "runs"
        {
	    var attributes,
	        substring,
	        runString;
	  
	    attributes = [text attributesAtIndex: CPMaxRange(currRange)
			     longestEffectiveRange:currRange
			     inRange: completeRange];
	    substring = [string substringWithRange:currRange];
	  
	    runString = [self runStringForString:substring
			    attributes:attributes
			    paragraphStart:first];
	    [result appendString: runString];
	    first = NO;
	}

        loc = CPMaxRange(completeRange);
    }

    return result;
}


- (CPString) RTFDStringFromAttributedString: (CPAttributedString)aText
	       documentAttributes: (CPDictionary)dict
{
    var output = [CPMutableString string],
        headerString,
        trailerString,
        bodyString;

    text = aText;
    docDict = dict;

  /*
   * do not change order! (esp. body has to be generated first; builds context)
   */
    bodyString = [self bodyString];
    trailerString = [self trailerString];
    headerString = [self headerString];

    [output appendString: headerString];
    [output appendString: bodyString];
    [output appendString: trailerString];
    return output;
}
@end