export type MenuItems = {
  heading: string;
  subItems: string[];
};

export type SideBarItems = {
  title: string;
  url: string;
  storagePath: string;
  childen?: [
    {
      title: string;
      url: string;
      storagePath: string;
    }
  ];
};

export type Post = {
  title: string;
  pubDate: string;
  description: string;
  author?: string;
  tags: string[];
};
