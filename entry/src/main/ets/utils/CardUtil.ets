export class CardUtil {
  public static getPostPageImageId(prePageClickedCardId: string | undefined): string | undefined {
    if (!prePageClickedCardId) {
      return undefined;
    }
    return 'Post_Page_Image_' + prePageClickedCardId;
  }

  public static getBannerItemId(bannerId: number): string {
    return 'Banner_Item_' + bannerId.toString();
  }
}
