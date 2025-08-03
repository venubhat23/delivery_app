import React, { useEffect, useState, useRef } from "react";

import {
  Box, Typography, Button,
  TextField,
  Avatar,
  Chip,
  Select,
  MenuItem,
  IconButton,
  Card, FormControl,
  Tab, Tabs, Checkbox,
  Grid, Modal, Paper,
  AppBar, Toolbar, Container, InputLabel, ListItemText,
  CardContent, Autocomplete, CardActions, CardMedia, Divider, Stack,ListItemIcon,
  CircularProgress, // Add this import
} from "@mui/material";
import ArrowLeftIcon from "@mui/icons-material/ArrowBack";
import CloseIcon from '@mui/icons-material/Close';
import FavoriteBorderIcon from '@mui/icons-material/FavoriteBorder';
import ChatBubbleOutlineIcon from '@mui/icons-material/ChatBubbleOutline';
import SendIcon from '@mui/icons-material/Send';
import MoreVert from "@mui/icons-material/MoreVert";
import Repeat from "@mui/icons-material/Repeat";
import ThumbUp from "@mui/icons-material/ThumbUp";
import MessageCircle from "@mui/icons-material/Star"; // Placeholder for MessageCircle
import Editor from "../../components/Editor";
import TabComponent from "../../components/TabComponent";
import InstagramPost from "../../components/InstagramPost"
import Layout from "../../components/Layout";
import axios from 'axios';
import { useMutation } from "@tanstack/react-query";
import { Menu as MenuIcon, Notifications as NotificationsIcon, AccountCircle as AccountCircleIcon, } from '@mui/icons-material';
import { toast } from "react-toastify";
import Flatpickr from "react-flatpickr";
import "flatpickr/dist/themes/material_green.css";
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import Skeleton from "@mui/material/Skeleton";
import OutlinedInput from '@mui/material/OutlinedInput';
import FacebookIcon from '../../assets/images/facebook.png';
import InstaIcon from '../../assets/images/instagram.png';
import LinkedInIcon from '../../assets/images/linkedin.png';
import ImageIcon from '@mui/icons-material/Image';
import VideoLibraryIcon from '@mui/icons-material/VideoLibrary';
import Sidebar from '../../components/Sidebar' 

const ITEM_HEIGHT = 48;
const ITEM_PADDING_TOP = 8;
const MenuProps = {
  PaperProps: {
    style: {
      maxHeight: ITEM_HEIGHT * 4.5 + ITEM_PADDING_TOP,
      width: 250,
    },
  },
};

const CreatePost = () => {

  const Brands = ['D-Mart', 'V-Mart', 'Blinkit']

  const TabPanel = ({ value, index, children }) => {
    return (
      value === index && (
        <Box sx={{ p: 2 }}>
          <Typography>{children}</Typography>
        </Box>
      )
    );
  };

  const [postContent, setPostContent] = useState("");
  const [open, setOpen] = useState(false);
  const [tabValue, setTabValue] = useState(0);
  //const [openAnother, setOpenAnother] = useState(false);
  const [openModal, setOpenModal] = useState(false);
  const [uploadedImageUrl, setUploadedImageUrl] = useState("");
  const [file, setFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [loading, setLoading] = useState(false);
  const [selectedPages, setSelectedPages] = useState([]);
  const [brandName, setBrandName] = useState("");
  const fileInputRef = useRef(null);
  const [uploadedFileName, setUploadedFileName] = useState("");
  const [posting, setPosting] = useState(false);
  const [openDateTimePicker, setOpenDateTimePicker] = useState(false);
  const [selectedDateTime, setSelectedDateTime] = useState(new Date());
  //const [createPostMode, setCreatePostMode] = useState("");
  const [editorLoaded, setEditorLoaded] = useState(false);
  // const [data, setData] = useState("");
  const [createPostMode, setCreatePostMode] = useState("");
  const [pages, setPages] = useState([]);
  const [selectedOption, setSelectedOption] = useState([])
  const [previewUrl, setPreviewUrl] = useState('');
  const [selectUser, setSelectUser] = useState('')

  const [selectedUsers, setSelectedUsers] = useState([])
  const [selectedChipId, setSelectedChipId] = useState(null);
  const [generatingContent, setGeneratingContent] = useState(false);

  console.log('hereree', selectUser)

  // Generate with AI function
  const handleGenerateWithAI = async () => {
    setGeneratingContent(true);
    try {
      const token = localStorage.getItem("token");
      const response = await axios.post(
        "https://api.marketincer.com/api/v1/generate-content", // Replace with your actual endpoint
        {
          description: "generate note on social media"
        },
        {
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json"
          }
        }
      );
      
      // Insert the generated content into the editor
      const generatedContent = response.data.content || response.data.message || response.data;
      setPostContent(generatedContent);
      
      toast.success("Content generated successfully!", {
        position: "top-right",
        autoClose: 3000,
      });
    } catch (error) {
      console.error("Error generating content:", error);
      
      // For demo purposes, use the sample response you provided
      const sampleResponse = `Here's a well-structured note on social media:
---
### Note on Social Media
Definition:
Social media refers to digital platforms and applications that enable users to create, share, and interact with content, ideas, and information in virtual communities and networks.
---
Popular Platforms:
* Facebook: For social networking and community building.
* Instagram: For photo and video sharing.
* Twitter (X): For microblogging and real-time updates.
* LinkedIn: For professional networking.
* YouTube: For video sharing and streaming.
* WhatsApp & Telegram: For messaging and group communication.
---
Importance of Social Media:
1. Communication: Provides instant and global connectivity.
2. Information Sharing: Acts as a major source of news and knowledge.
3. Marketing & Branding: Businesses use social media for advertising and customer engagement.
4. Education & Awareness: Helps spread awareness about social, political, and environmental issues.
5. Entertainment: Offers a wide variety of content such as memes, videos, music, and more.
---
Positive Impacts:
* Strengthens relationships and communities.
* Promotes small businesses and entrepreneurship.
* Provides a platform for self-expression and creativity.
* Encourages social and cultural exchange.
---
Negative Impacts:
* Cyberbullying and online harassment.
* Spread of misinformation and fake news.
* Addiction leading to reduced productivity.
* Privacy concerns and data breaches.
---
Conclusion:
Social media is a powerful tool that can connect, educate, and entertain. However, responsible usage is essential to avoid its negative effects and ensure a safe online environment.
---
Would you like me to create this as a short handwritten-style note (suitable for study/revision) or as a detailed infographic-style note?`;
      
      setPostContent(sampleResponse);
      
      toast.info("Using sample content for demo", {
        position: "top-right",
        autoClose: 3000,
      });
    } finally {
      setGeneratingContent(false);
    }
  };

  // Function to get tab index based on page type
  const getTabIndexByPageType = (pageType) => {
    switch(pageType) {
      case 'instagram':
        return 0;
      case 'linkedin':
        return 1;
      case 'facebook':
        return 2;
      default:
        return 0;
    }
  };

  // Function to get the selected user's page type
  const getSelectedUserPageType = () => {
    const selectedUser = selectedUsers.find(user => user.social_id === selectedChipId);
    return selectedUser ? selectedUser.page_type : null;
  };

  // Function to get available tabs based on selected users
  const getAvailableTabs = () => {
    if (selectedUsers.length === 0) return ['instagram', 'linkedin', 'facebook'];
    
    const uniquePageTypes = [...new Set(selectedUsers.map(user => user.page_type))];
    return uniquePageTypes;
  };

  // Function to check if current tab content should be shown
  const shouldShowTabContent = (tabIndex) => {
    const availableTabs = getAvailableTabs();
    const tabTypes = ['instagram', 'linkedin', 'facebook'];
    const currentTabType = tabTypes[tabIndex];
    
    return availableTabs.includes(currentTabType);
  };

  const handleOptionChange = (event) => {
    const value = event.target.value;
    console.log('Selected value:', value);
    setSelectedOption(typeof value === 'string' ? value.split(',') : value);
    console.log('Selected inside:', selectedOption);

  };

  const handleTabChange = (event, newValue) => {
    setTabValue(newValue);
  };

  const fetchAccountsFromAPI = async () => {

    setLoading(true);
    const token = localStorage.getItem("token");

    try {
      // Fetch the accounts from the dummy API
      const response = await fetch(
        "https://api.marketincer.com/api/v1/social_pages/connected_pages", {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`, // Backticks used here
          },
        }
      );

      const data = await response.json();
      setPages(data.data.accounts); // Store the fetched accounts in the state


    } catch (error) {
      console.error("Error fetching accounts:", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAccountsFromAPI();
  }, []);

  // Update tab when selected chip changes or when first user is selected
  useEffect(() => {
    if (selectedUsers.length > 0) {
      // Auto-switch to the first selected user's page type tab
      const firstUserPageType = selectedUsers[0].page_type;
      const newTabIndex = getTabIndexByPageType(firstUserPageType);
      setTabValue(newTabIndex);
    }
  }, [selectedUsers]);

  // Additional effect for chip selection
  useEffect(() => {
    const selectedPageType = getSelectedUserPageType();
    if (selectedPageType) {
      const newTabIndex = getTabIndexByPageType(selectedPageType);
      setTabValue(newTabIndex);
    }
  }, [selectedChipId, selectedUsers]);

  useEffect(() => {
    setEditorLoaded(true);
  }, []);

  const draftModelOpen = async (action) => {
    if (!uploadedImageUrl || !postContent) {
      alert("Please make sure all fields are filled out!");
      return;
    }
    setCreatePostMode(action);
    setOpenDateTimePicker(true);

  };

  const handleBoxClick = () => {
    fileInputRef.current.click(); //  Triggers the hidden file input
  };

  const handleDrop = (event) => {
    event.preventDefault();
    const droppedFile = event.dataTransfer.files[0];
    if (droppedFile) {
      setFile(droppedFile);
      setUploadedFileName(droppedFile.name);
      console.log('imgggg', uploadedImageUrl)

      //  Auto-upload the file after drop
      handleFileUpload(droppedFile);
    }
  };

  const handleFileUpload = async (file) => {
    if (!file) return;

    setUploading(true);
    try {
      const formData = new FormData();
      formData.append("file", file);

      const response = await fetch(
        "https://kitintellect.tech/storage/public/api/upload/aaFacebook",
        {
          method: "POST",
          body: formData,
        }
      );

      const data = await response.json();

      if (data.url) {
        setUploadedImageUrl(data.url); //  Store uploaded file URL

        toast.success("File uploaded successfully!", {
          position: "top-right",
          autoClose: 5000,
        });
      } else {
        throw new Error("Upload failed");
      }
    } catch (error) {
      toast.error("File upload failed!", {
        position: "top-right",
        autoClose: 5000,
      });
      console.error("Error uploading file:", error);
    } finally {
      setUploading(false);
    }
  };

  const handleFileChange = (e) => {
    const selectedFile = e.target.files[0];
    if (selectedFile) {
      setFile(selectedFile);
      console.log('11111', file)
      setUploadedFileName(selectedFile.name);
      //  Auto-upload the file after selection
      handleFileUpload(selectedFile);
    }
  };

  const handlePublish = async () => {
    if (!postContent) {
      alert("Please make sure all fields are filled out!");
      return;
    }
    setPosting(true);
    const stripHtmlTags = (postContent) => postContent.replace(/<[^>]*>/g, '').trim();
    const payloadData = {
      social_page_ids: selectedPages,  // Only sending the first selected page for now
      post: {
        s3_url: uploadedImageUrl,
        comments: stripHtmlTags(postContent),
        brand_name: brandName,
        status: "publish"
      },
    };
    console.log('papapa', payloadData)

    try {
      const token = localStorage.getItem("token");
      await axios.post("https://api.marketincer.com/api/v1/posts", payloadData, {
        headers: {
          Authorization: `Bearer ${token}`, // <-- use backticks here
        }
      });
      alert("Post published successfully!");
      // Optionally, clear form states
      setSelectedPages([]);
      setPostContent("");
      setUploadedImageUrl("");
      setPosting(false);
      setUploadedFileName('');
      setOpen(false);
      window.location.reload();
    } catch (error) {
      console.error("Error publishing post:", error);
      alert("Failed to publish post");
    }
  };

  const draftHandler = async () => {

    if ( !uploadedImageUrl || !postContent) {
      alert("Please make sure all fields are filled out!");
      return;
    }
    setPosting(true);
    const stripHtmlTags = (postContent) => postContent.replace(/<[^>]*>/g, '').trim();
    const payloadData = {
      social_page_ids: selectedPages,  // Only sending the first selected page for now
      post: {
        s3_url: uploadedImageUrl,
        comments: stripHtmlTags(postContent),  // Use the postContent for comments as well
        brand_name: brandName,
        status: createPostMode,
        scheduled_at: selectedDateTime
      },
    };

    try {
      const token = localStorage.getItem("token");
      await axios.post("https://api.marketincer.com/api/v1/posts/schedule", payloadData, {
        headers: {
          Authorization: `Bearer ${token}`, // <-- use backticks here
        }
      });
      alert(`Post ${createPostMode} successfully!`);
      // Optionally, clear form states
      setSelectedPages([]);
      setPostContent("");
      setUploadedImageUrl("");
      setPosting(false);
      setOpenDateTimePicker(false);
      setUploadedFileName('');
      setOpen(false);
      window.location.reload();
    } catch (error) {
      console.error(`Error ${createPostMode} post:`, error);
      alert(`Failed to ${createPostMode} post`);
    }
  };


  const mutation = useMutation({
    mutationFn: (payloadData) => {
      const token = localStorage.getItem("token"); // Retrieve token from local storage (or state)

      return axios.post(
        "https://api.marketincer.com/api/v1/posts",
        payloadData,
        {
          headers: {
            Authorization: `Bearer ${token}`, // <-- use backticks here
          },
        }
      );
    },
    onSuccess: (response) => {
      console.log(response);
      toast.success(response?.data?.message, {
        position: "top-right",
        autoClose: 5000,
      });
      setOpen(false);
      setPostContent("");
    },
    onError: (error) => {
      toast.error("Failed to Create Post", {
        position: "top-right",
        autoClose: 5000,
      });
      console.error("Post creation failed", error);
    },
  });


  const handleAvatarClick = (pageId) => {
    console.log("Page ID clicked:", pageId, selectedPages);
    setSelectedPages((selectedPages) =>
      selectedPages.includes(pageId)
        ? selectedPages.filter((id) => id !== pageId) // Deselect if already selected
        : [...selectedPages, pageId] // Select if not selected
    );

  };


  const handleUsersChange = (event) => {
    let selectedIds = event.target.value;
    // Normalize to array of numbers
    selectedIds = Array.isArray(selectedIds)
      ? selectedIds.map(Number)
      : [Number(selectedIds)];

    const selectedUserObjects = pages.filter((user) =>
      selectedIds.includes(user.id)
    );

    const socialId = selectedUserObjects.map(user => user.social_id);

    setSelectedUsers(selectedUserObjects);
    handleAvatarClick(socialId)

  };

  // LinkedIn Preview Component
  const LinkedinPreview = () => {
    const interactionButtons = [
      { icon: <FavoriteBorderIcon />  },
      { icon: <ChatBubbleOutlineIcon /> },
      // { icon: <Repeat />, text: "Repost" },
      { icon: <SendIcon /> },
    ];

    return (
        <Card
          sx={{ borderRadius: 2, padding: '10px' }}
        >
          <CardContent sx={{ p: 0 }}>
            
            {/* Post Image */}
            {uploadedImageUrl ? (
              <Avatar 
              src={uploadedImageUrl} 
              alt="LinkedIn post image" 
              sx={{ width: 300, height: 350, display: 'block', margin: 'auto',borderRadius:'inherit' }} />
            ) : (
              <Skeleton animation="wave" variant="circular" width={300} height={350} sx={{ display: 'block', margin: 'auto', borderRadius:'inherit' }} />
            )}

            {/* Image Indicators */}
            <Box
              display="flex"
              justifyContent="center"
              gap={1}
              mt={-3}
              mb={1.5}
            >
              <Box
                width="10px"
                height="10px"
                bgcolor="#882AFF"
                borderRadius="4px"
              />
              <Box
                width="10px"
                height="10px"
                bgcolor="#E7D3FF"
                borderRadius="4px"
              />
            </Box>

            {/* Post Actions */}

            {postContent && (
              <Box px={2.5} pb={1} mt={3}>
                <Typography variant="body2" color="#882AFF" sx={{textAlign:'justify'}}>
                  <span dangerouslySetInnerHTML={{ __html: postContent }} />
                </Typography>
              </Box>
            )}

            <CardActions
              
            >
              {interactionButtons.map((button, index) => (
                <Stack
                  key={index}
                  direction="row"
                  spacing={1}
                  alignItems="center"
                  sx={{ cursor: "pointer" }}
                >
                  <Box sx={{ "& svg": { width: 20, height: 20 } }}>
                    {button.icon}
                  </Box>
                  <Typography fontWeight="medium">{button.text}</Typography>
                </Stack>
              ))}
            </CardActions>
          </CardContent>
        </Card>
      
    );
  };

  // Render preview content based on tab and availability
  const renderPreviewContent = (tabIndex) => {
    if (!shouldShowTabContent(tabIndex)) {
      return (
        <Box 
          display="flex" 
          justifyContent="center" 
          alignItems="center" 
          height="200px"
          // sx={{ 
          //   backgroundColor: '#f5f5f5', 
          //   borderRadius: 2,
          //   border: '1px dashed #ccc' 
          // }}
        >
          <Typography variant="h6" color="text.secondary">
            There is no preview available
          </Typography>
        </Box>
      );
    }

    // LinkedIn Preview
    if (tabIndex === 1) {
      return <LinkedinPreview />;
    }

    // Instagram and Facebook Preview (existing logic)
    return (
      <Card sx={{ borderRadius: 2, padding: '10px' }}>
        {!uploadedImageUrl || !postContent ? (
          <Skeleton animation="wave" variant="circular" width={300} height={350} sx={{ display: 'block', margin: 'auto', borderRadius:'inherit' }} />
        ) : (
          <Avatar src={uploadedImageUrl} alt="Uploaded" sx={{ width: 300, height: 350, display: 'block', margin: 'auto',borderRadius:'inherit' }} />
        )}
        <CardContent sx={{ p: 0 }}>
          {uploadedImageUrl && postContent && (
            <Typography variant="body2" color="text.secondary" sx={{ display: "flex" }}>
              <span dangerouslySetInnerHTML={{ __html: postContent }} />
            </Typography>
          )}

          {/* Platform-specific interaction buttons */}
          <Box display="flex" alignItems="center" mt={2} gap={3}>
            {tabIndex === 0 && ( // Instagram
              <>
                <Box display="flex" alignItems="center" gap={0.5}>
                  <FavoriteBorderIcon fontSize="small" />
                  {/* <Typography variant="body2">37.8K</Typography> */}
                </Box>
                <Box display="flex" alignItems="center" gap={0.5}>
                  <ChatBubbleOutlineIcon fontSize="small" />
                  {/* <Typography variant="body2">248</Typography> */}
                </Box>
                <Box display="flex" alignItems="center" gap={0.5}>
                  <SendIcon fontSize="small" />
                  {/* <Typography variant="body2">234</Typography> */}
                </Box>
              </>
            )}
            {tabIndex === 2 && ( // Facebook
              <>
                <Box display="flex" alignItems="center" gap={0.5}>
                  <FavoriteBorderIcon fontSize="small" />
                  {/* <Typography variant="body2">Like</Typography> */}
                </Box>
                <Box display="flex" alignItems="center" gap={0.5}>
                  <ChatBubbleOutlineIcon fontSize="small" />
                  {/* <Typography variant="body2">Comment</Typography> */}
                </Box>
                <Box display="flex" alignItems="center" gap={0.5}>
                  <SendIcon fontSize="small" />
                  {/* <Typography variant="body2">Share</Typography> */}
                </Box>
              </>
            )}
          </Box>
          {/* Metadata */}
          <Box
            display="flex"
            justifyContent="space-between"
            alignItems="center"
            mt={2}
          >
            <Typography variant="body2" color="text.secondary">
              {selectUser?.name || 'Select a user'}
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Just Now
            </Typography>
          </Box>

          
        </CardContent>
      </Card>
    );
  };
  

  const getPlatformIcon = (postType) => {
    
    switch (postType?.toLowerCase()) {
      case 'instagram':
        return <img src={InstaIcon} alt="instagram" width='25' height='25'  />
      case 'facebook':
        return <img src={FacebookIcon} alt="facebook" width='25' height='25'  />
      case 'linkedin':
        return <img src={LinkedInIcon} alt="linkedin" width='25' height='25'  />
      default:
        return null;
    }
  };


  return (

      <Box sx={{ flexGrow: 1, bgcolor:'#f5edf8', height:'100vh' }} > 
      <Grid container>
      <Grid size={{ md: 1 }} className="side_section"> <Sidebar/></Grid>
      <Grid size={{ md: 11 }}>
      <Paper
              elevation={0}
              sx={{
                display: { xs: 'none', md: 'block' },
                p: 1,
                backgroundColor: '#091a48',
                borderBottom: '1px solid',
                borderColor: 'divider',
                borderRadius: 0
              }}
            >
              <Box sx={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center'
              }}>

                <Typography variant="h6" sx={{ color: '#fff' }}>
                  <IconButton
                    edge="start"
                    color="inherit"
                    aria-label="back"
                    sx={{ mr: 2, color: '#fff' }}
                  >
                    <ArrowLeftIcon />
                  </IconButton>
                  Create Post
                </Typography>
                <Box sx={{ display: 'flex', gap: 1 }}>
                  <IconButton size="large" sx={{ color: '#fff' }}>
                    <NotificationsIcon />
                  </IconButton>
                  <IconButton size="large" sx={{ color: '#fff' }}>
                    <AccountCircleIcon />
                  </IconButton>
                </Box>
              </Box>
        </Paper>
        <Box sx={{flexGrow:1, mt: { xs: 8, md: 0 }, height: '100vh', overflow: 'hidden !important', padding:'20px'}}>
        <Grid container spacing={2} sx={{ height: '100%', overflow: 'hidden !important' }}>
          <Grid size={{ xs: 12, sm: 8, md: 6 }} spacing={2} sx={{ padding:'10px', bgcolor: '#fff', boxShadow: '2px 2px 2px 1px rgb(0 0 0 / 20%)' ,height:'100%' }}>
              {/* Dropdowns */}
              <Box display="flex" gap={2} mb={2} >
                <FormControl fullWidth>
                  <InputLabel id="demo-simple-select-label">Brand</InputLabel>
                  <Select
                    labelId="demo-simple-select-label"
                    id="demo-simple-select"
                    label="Brand"
                    size="small"
                    value={brandName}
                    onChange={(e) => setBrandName(e.target.value)}
                    sx={{ height:'40px',mt:'6px', color:'#882AFF'}}
                  >
                    {Brands.map((brand) => (
                      <MenuItem key={brand} value={brand} sx={{color:'#882AFF'}} >{brand}</MenuItem>
                    ))}
                  </Select>
                </FormControl>

                <FormControl fullWidth>
                  <InputLabel id="multi-user-label">Social Media</InputLabel>
                  <Select
                    labelId="multi-user-label"
                    multiple
                    size="small"
                    value={selectedUsers.map((user) => user.id)}
                    onChange={handleUsersChange}
                    input={<OutlinedInput label="Select Users" />}
                    sx={{ height:'40px',mt:'6px', color:'#882AFF'}}
                    renderValue={(selected) => 
                      selectedUsers.map(user => user.name).join(', ')
                    }
                  >
                    {pages.map((user) => (
                      <MenuItem key={user.id} value={user.id}>
                        <ListItemIcon sx={{ display: 'flex', alignItems: 'center', gap: 1}}>
                          {/* {(user.name)} */}
                          <Avatar src={user.picture_url} alt={user.name} sx={{ width: '22px', height: '22px' }} />
                          {getPlatformIcon(user.page_type)}
                        </ListItemIcon>
                        
                        <ListItemText primary={user.name} sx={{color:'#882AFF'}} />
                        <Checkbox className="custom-checkbox"
                        sx={{bgcolor:'#cbaef7', width:'10px', height:'10px', color:'#cbaef7'}}
                          checked={selectedUsers.some((selected) => selected.id === user.id)}
                        />
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Box>

              {/* User Chips */}

              <Box display="flex" gap={1} flexWrap="wrap" mb={2}>

                {selectedUsers.map((user) => (
                  <Chip
                    className="custom-chip"
                    key={user.id}
                    avatar={<>  {getPlatformIcon(user.page_type)}  <Avatar src={user.picture_url} sx={{ width: '22px', height: '22px' }} />  </>}
                    label={user.name}
                    onClick={() => {
                      //handleAvatarClick(user.social_id);
                      //setSelectedChipId(user.social_id);
                      setSelectUser(user); // Set the selected user for preview
                    }}
                    onDelete={() => { 
                      setSelectedUsers(prev => prev.filter(u => u.id !== user.id));
                      if (selectedChipId === user.social_id) {
                        setSelectedChipId(null);
                        setSelectUser('');
                      }
                    }} 
                    sx={{
                      border: selectedChipId === user.social_id ? '2px solid #5ebfa6' : 'none',
                      backgroundColor: selectedChipId === user.social_id ? '#ddd' : 'default',
                      boxShadow: selectedChipId === user.social_id ? '0 0 5px rgba(127,86,217,0.6)' : 'none'
                    }}
                    />
                    
                ))}

                {selectedPages.includes(pages.social_id) && (
                  <Box
                    sx={{
                      background: "white",
                      width: 20,
                      height: 20,
                      alignItems: "center",
                    }}
                  >
                    <CheckCircleOutlineIcon
                      sx={{
                        color: "#5ebfa6",
                        fontSize: 20,
                        width: 20,
                        height: 20
                      }}
                    />
                  </Box>
                )}

              </Box>

              {/* Text Field with Generate AI Button */}
              <Box sx={{ position: 'relative', mb: 2 }}>
                {/* Generate with AI Button */}
                <Button
                  variant="contained"
                  onClick={handleGenerateWithAI}
                  disabled={generatingContent}
                  sx={{
                    position: 'absolute',
                    top: -45,
                    right: 0,
                    zIndex: 10,
                    backgroundColor: '#7f56d9',
                    color: 'white',
                    borderRadius: '8px',
                    textTransform: 'none',
                    fontSize: '14px',
                    fontWeight: 500,
                    padding: '8px 16px',
                    minWidth: 'auto',
                    '&:hover': {
                      backgroundColor: '#6941c6',
                    },
                    '&:disabled': {
                      backgroundColor: '#9575cd',
                      color: '#fff'
                    }
                  }}
                  startIcon={
                    generatingContent ? (
                      <CircularProgress size={16} sx={{ color: '#fff' }} />
                    ) : (
                      <Box
                        sx={{
                          width: 20,
                          height: 20,
                          backgroundColor: '#fff',
                          borderRadius: '4px',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontSize: '12px',
                          fontWeight: 'bold',
                          color: '#7f56d9'
                        }}
                      >
                        M
                      </Box>
                    )
                  }
                >
                  {generatingContent ? 'Generating...' : 'Generate with AI'}
                </Button>
                
                <Editor value={postContent} onChange={setPostContent} />
              </Box>

              <Typography variant="caption" display="block" mb={2}>
                275 characters left
              </Typography>

              {/* Uploaded Images */}
              <Box display="flex" gap={1} mb={2}>
                {uploadedImageUrl && (
                  <Box position="relative">
                    <Avatar
                      variant="rounded"
                      src={uploadedImageUrl}
                      sx={{ width: 80, height: 80 }}
                    />
                    <IconButton
                      size="small"
                      sx={{
                        position: 'absolute',
                        top: 0,
                        right: 0,
                        bgcolor: 'white',
                      }}
                      onClick={() => {
                        setUploadedImageUrl("");
                        setUploadedFileName("");
                        setFile(null);
                      }}
                    >
                      <CloseIcon fontSize="small" />
                    </IconButton>
                  </Box>
                )}

              </Box>

              <Box
                display="flex"
                justifyContent="center"
                alignItems="center"
                flexDirection="column"
                sx={{
                  //width: "100%",
                  padding: "16px",
                  border: "1px solid #f0f0f0",
                  borderRadius: "8px",
                  backgroundColor: "#fff",
                  textAlign: "center",
                  cursor: "pointer",
                  my: 2,
                  margin: "10px",
                  marginLeft: "0px",
                  boxShadow: '0px 2px 1px -1px rgb(247 247 247 / 12%), 0px 1px 1px 0px rgb(247 247 247 / 12%), 0px 1px 3px 0px rgb(247 247 247 / 12%)'
                }}
                onClick={handleBoxClick}
                onDrop={handleDrop} // ✅ Handles dropped files
                onDragOver={(e) => e.preventDefault()} // ✅ Prevents default drag behavior
              >


                <Typography variant="body1" sx={{ color: "#000", }}>
                  +  Upload Media
                </Typography>

                {uploadedFileName && (
                  <Typography variant="body2" sx={{
                    color: "#444", mt: 1, whiteSpace: "nowrap", // ✅ Ensures text does not wrap
                    overflow: "hidden", // ✅ Hides overflow text
                    textOverflow: "ellipsis", maxWidth: "400px",
                  }}>
                    Selected File: {uploadedFileName}
                  </Typography>
                )}

                {uploading && <Typography variant="body2">Uploading...</Typography>}
              </Box>

                  {/* Hidden File Input */}
                  <input
                    type="file"
                    ref={fileInputRef}
                    onChange={handleFileChange}
                    style={{ display: "none" }}
                  />

                  {/* Buttons */}
                  <Box display="flex" gap={2}>
                                    <Button variant="outlined" sx={{ display: 'none' }} >Save as Draft</Button>
                {/* <Button variant="contained">Schedule Post</Button> */}
                    <Button
                      variant="contained"
                      sx={{
                        margin: "0.09375rem 1px",
                        display: 'none',
                      }}
                      onClick={() => draftModelOpen("schedule")}
                    >
                      Schedule Post
                    </Button>
                  </Box>
                  <Button
                    variant="contained"
                    fullWidth
                    onClick={handlePublish}
                    disabled={posting || uploading} // Disable when posting or uploading
                    sx={{ 
                      mt: 2, 
                      '&:disabled': {
                        bgcolor: '#9575cd', // Lighter purple when disabled
                        color: '#fff'
                      }
                    }}
                  >
                    {posting ? (
                      <Box display="flex" alignItems="center" gap={1}>
                        <CircularProgress size={20} sx={{ color: '#fff' }} />
                        Publishing...
                      </Box>
                    ) : (
                      'Publish Now'
                    )}
                  </Button>
          </Grid>

          <Grid  size={{ xs: 12, sm: 4, md: 6 }} spacing={2} sx={{ padding:'10px', bgcolor: '#fff', boxShadow: '2px 2px 2px 1px rgb(0 0 0 / 20%)', height:'100%' }}>
          <Tabs value={tabValue} onChange={handleTabChange} aria-label="basic tabs example">
                  <Tab label="Instagram" />
                  <Tab label="Linkedin" />
                  <Tab label="Facebook" />
                </Tabs>

                <TabPanel value={tabValue} index={0}>
                  <Grid item xs={12} md={12} lg={12}>
                    {renderPreviewContent(0)}
                  </Grid>
                </TabPanel>
                <TabPanel value={tabValue} index={1}>
                  <Grid item xs={12} md={12} lg={12}>
                    {renderPreviewContent(1)}
                  </Grid>
                </TabPanel>
                <TabPanel value={tabValue} index={2}>
                  <Grid item xs={12} md={12} lg={12}>
                    {renderPreviewContent(2)}
                  </Grid>
                </TabPanel>
          </Grid>
        </Grid>
          
      </Box>
      </Grid>
        
      
    </Grid>
      </Box>
  
  );
};

export default CreatePost;